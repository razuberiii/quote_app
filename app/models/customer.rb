class Customer < ApplicationRecord
  FOLLOW_UP_EMAIL_COOLDOWN = 10.minutes
  ENGAGEMENT_STATES = %w[unassessed active cooling at_risk dormant archived].freeze
  FOLLOW_UP_REQUIRED_STATES = %w[cooling at_risk].freeze

  SALES_STATUSES = %w[new contacted quoting negotiating won lost inactive].freeze
  LEGACY_STATUSES = %w[potential following closed paused].freeze
  CUSTOMER_LEVELS = %w[normal vip distributor key_account].freeze
  CUSTOMER_SOURCES = %w[alibaba exhibition google_seo referral old_customer other].freeze
  PAYMENT_TERMS_OPTIONS = %w[t_t l_c oa mixed].freeze
  TAX_ID_TYPES = %w[VAT GST TIN RFC CNPJ CUIT NIT RUT OTHER].freeze
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_AVATAR_SIZE = 5.megabytes

  belongs_to :company
  if column_names.include?("internal_owner_id")
    belongs_to :internal_owner, class_name: "User", optional: true
  end
  has_many :quotes, dependent: :destroy
  has_many :customer_follow_up_events, -> { recent_first }, dependent: :destroy
  has_many :customer_taggings, -> { ordered }, dependent: :destroy
  has_many :customer_tags, through: :customer_taggings
  has_one_attached :avatar

  before_validation :normalize_phone_country_code, :set_default_status, :set_default_customer_level, :set_default_engagement_state

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :customer_level, inclusion: { in: CUSTOMER_LEVELS }
  validates :customer_source, inclusion: { in: CUSTOMER_SOURCES }, allow_blank: true
  validates :payment_terms, inclusion: { in: PAYMENT_TERMS_OPTIONS }, allow_blank: true
  validates :estimated_annual_volume, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true
  validates :engagement_state, inclusion: { in: ENGAGEMENT_STATES }, if: -> { self.class.column_names.include?("engagement_state") }
  validates :manual_engagement_override, inclusion: { in: [ true, false ] }, if: -> { self.class.column_names.include?("manual_engagement_override") }
  validate :internal_owner_within_company
  validate :avatar_constraints

  scope :search, ->(query) {
    return all if query.blank?

    query = "%#{query}%"
    where(
      "name ILIKE ? OR country ILIKE ? OR contact_name ILIKE ? OR email ILIKE ?",
      query, query, query, query
    )
  }

  def mark_followed_today!(user: nil, channel: "manual", quote: nil, note: nil, metadata: {})
    return record_follow_up!(user:, channel:, quote:, note:, metadata:) if user.present?

    persist_follow_up_dates!(Date.today)
  end

  def record_follow_up!(user:, channel: "manual", quote: nil, note: nil, contacted_at: Time.current, metadata: {})
    touch_time = contacted_at || Time.current

    transaction do
      event = customer_follow_up_events.create!(
        user: user,
        quote: quote,
        channel: channel,
        contacted_at: touch_time,
        note: note,
        metadata: metadata.presence || {}
      )

      persist_follow_up_dates!(touch_time.to_date)

      event
    end
  end

  def follow_up_overdue?
    return false unless follow_up_reminders_enabled?

    next_follow_up_date.present? && next_follow_up_date < Date.today
  end

  def follow_up_due_today?
    return false unless follow_up_reminders_enabled?

    next_follow_up_date.present? && next_follow_up_date == Date.today
  end

  def follow_up_upcoming?
    return false unless follow_up_reminders_enabled?

    next_follow_up_date.present? &&
      next_follow_up_date > Date.today &&
      next_follow_up_date <= Date.today + 7.days
  end

  def follow_up_status
    return "normal" unless follow_up_reminders_enabled?

    return "overdue" if follow_up_overdue?
    return "today" if follow_up_due_today?
    return "upcoming" if follow_up_upcoming?
    "normal"
  end

  def follow_up_reminders_enabled?
    !%w[lost inactive].include?(status_css)
  end

  def manual_engagement_override?
    return false unless self.class.column_names.include?("manual_engagement_override")

    !!manual_engagement_override
  end

  def quote_view_events_relation
    QuoteViewEvent
      .joins(quote_share: :quote)
      .where(quotes: { customer_id: id })
  end

  def last_activity_at
    [
      quotes.not_archived.maximum(:created_at),
      latest_quote_view_signal_at,
      customer_follow_up_events.maximum(:contacted_at)
    ].compact.max
  end

  def computed_engagement_state(now: Time.current)
    return "unassessed" if unassessed_for_engagement?

    activity_at = last_activity_at
    return "active" if activity_at.present? && activity_at >= 14.days.ago(now)
    return "dormant" if activity_at.present? && activity_at < 90.days.ago(now)
    if open_quotes_for_engagement? && activity_at.present? && activity_at < 60.days.ago(now)
      return "at_risk"
    end
    return "cooling" if activity_at.present? && activity_at < 30.days.ago(now)

    "active"
  end

  def effective_engagement_state(now: Time.current)
    return "archived" if engagement_state.to_s == "archived"
    return engagement_state if manual_engagement_override? && engagement_state.present?

    computed_engagement_state(now: now)
  end

  def refresh_engagement_state!(now: Time.current)
    return if manual_engagement_override?
    return unless self.class.column_names.include?("engagement_state")

    resolved = computed_engagement_state(now: now)
    return if engagement_state.to_s == resolved

    update_columns(engagement_state: resolved, updated_at: Time.current)
  end

  def can_send_follow_up_email?(now: Time.current)
    seconds_until_follow_up_email_allowed(now:) <= 0
  end

  def seconds_until_follow_up_email_allowed(now: Time.current)
    last_email_at = customer_follow_up_events.where(channel: "email").maximum(:contacted_at)
    return 0 if last_email_at.blank?

    elapsed_seconds = (now - last_email_at).to_i
    [ FOLLOW_UP_EMAIL_COOLDOWN.to_i - elapsed_seconds, 0 ].max
  end

  def status_label
    normalized = status_css
    I18n.t("customers.status_labels.#{normalized}", default: status.to_s.humanize.presence || I18n.t("customers.status_labels.new", default: "New"))
  end

  def status_css
    normalized = status.to_s.parameterize(separator: "_")
    normalized.presence || "new"
  end

  def avatar_initial
    name.to_s.strip.first&.upcase || "?"
  end

  def ordered_tag_names
    customer_taggings.includes(:customer_tag).map { |tagging| tagging.customer_tag.name }
  end

  def ordered_customer_tags
    customer_taggings.includes(:customer_tag).map(&:customer_tag)
  end

  def internal_owner_display_name
    return "-" unless internal_owner_enabled?
    return "-" unless respond_to?(:internal_owner) && internal_owner

    internal_owner.full_name.presence || internal_owner.email
  end

  def self.internal_owner_enabled?
    column_names.include?("internal_owner_id")
  end

  def internal_owner_enabled?
    self.class.internal_owner_enabled?
  end

  def formatted_phone
    [ phone_country_code.to_s.strip.presence, phone.to_s.strip.presence ].compact.join(" ").presence
  end

  def whatsapp_phone
    [ phone_country_code.to_s.gsub(/\D+/, "").presence, phone.to_s.gsub(/\D+/, "").presence ].compact.join.presence
  end

  def persist_follow_up_dates!(date)
    update_columns(
      last_follow_up_date: date,
      next_follow_up_date: date + 3.days,
      updated_at: Time.current
    )
  end

  private

  def normalize_phone_country_code
    normalized = phone_country_code.to_s.gsub(/\s+/, "").presence
    self.phone_country_code = normalized.present? ? normalized.sub(/\A(?!\+)/, "+") : nil
  end

  def set_default_status
    self.status = "new" if status.blank?
  end

  def set_default_customer_level
    self.customer_level = "normal" if customer_level.blank?
  end

  def set_default_engagement_state
    return unless self.class.column_names.include?("engagement_state")

    self.engagement_state = "unassessed" if engagement_state.blank?
  end

  def unassessed_for_engagement?
    return false if quotes.not_archived.exists?
    return false if customer_follow_up_events.exists?

    latest_quote_view_signal_at.blank?
  end

  def open_quotes_for_engagement?
    quotes.not_archived.where(status: Quote::OPEN_STATUSES).exists?
  end

  def latest_quote_view_signal_at
    last_share_view = QuoteShare
      .joins(:quote)
      .where(quotes: { customer_id: id })
      .maximum(:last_viewed_at)
    first_share_view = QuoteShare
      .joins(:quote)
      .where(quotes: { customer_id: id })
      .maximum(:first_viewed_at)

    [
      quotes.not_archived.maximum(:viewed_at),
      last_share_view,
      first_share_view
    ].compact.max
  end

  def internal_owner_within_company
    return unless internal_owner_enabled?
    return unless respond_to?(:internal_owner)
    return if internal_owner.blank? || internal_owner.company_id == company_id

    errors.add(:internal_owner, "must belong to the same company")
  end

  def avatar_constraints
    return unless avatar.attached?

    if !AVATAR_CONTENT_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be PNG, JPG, WEBP, or GIF")
    end
    if avatar.blob.byte_size > MAX_AVATAR_SIZE
      errors.add(:avatar, "must be smaller than #{MAX_AVATAR_SIZE / 1.megabyte}MB")
    end
  end
end
