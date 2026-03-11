class ActionItem < ApplicationRecord
  LEGACY_ACTION_TYPES = %w[
    quote_viewed
    quote_not_viewed
    quote_expiring
  ].freeze

  ACTION_TYPES = %w[
    follow_up_due
    win_reason_missing
    loss_reason_missing
    revision_requested
    expiring_soon
    hot_engagement_no_follow_up
    viewed_no_follow_up
    not_viewed_3d
    not_viewed_7d
    stalled_negotiation
  ].freeze

  belongs_to :user
  belongs_to :reference, polymorphic: true

  validates :action_type, inclusion: { in: ACTION_TYPES + LEGACY_ACTION_TYPES }
  validates :reference_type, :reference_id, presence: true

  scope :unresolved, -> { where(resolved_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  def resolved?
    resolved_at.present?
  end

  def message
    return I18n.t("action_items.#{action_type}.label", reference: reference_label) if I18n.exists?("action_items.#{action_type}.label")
    return I18n.t("dashboard.logic.action_items.#{action_type}", reference: reference_label) if I18n.exists?("dashboard.logic.action_items.#{action_type}")

    I18n.t("signals.#{action_type}", default: reference_label)
  end

  def headline
    return quote_display_name if reference.is_a?(Quote)

    reference_label
  end

  def secondary_text
    return "#{reference.quote_no} • #{message}" if reference.is_a?(Quote)

    message
  end

  def reference_label
    return reference.quote_no if reference.respond_to?(:quote_no)
    return reference.name if reference.respond_to?(:name)

    reference_type.to_s
  end

  def priority
    return :urgent if %w[win_reason_missing loss_reason_missing].include?(action_type)
    return :urgent if %w[revision_requested expiring_soon hot_engagement_no_follow_up].include?(action_type)
    return :watch if action_type == "follow_up_due"
    return :risk if action_type == "not_viewed_7d"
    return :watch if %w[viewed_no_follow_up not_viewed_3d stalled_negotiation].include?(action_type)
    return :urgent if action_type == "quote_expiring"
    return :watch if %w[quote_viewed].include?(action_type)
    return :normal if action_type == "quote_not_viewed"

    :normal
  end

  def priority_rank
    { urgent: 0, risk: 1, watch: 2, normal: 3 }.fetch(priority, 4)
  end

  private

  def quote_display_name
    return reference.custom_title if reference.respond_to?(:custom_title) && reference.custom_title.present?

    first_item = reference.quote_items.ordered.first if reference.respond_to?(:quote_items)
    first_item&.product&.name.presence ||
      first_item&.description.presence ||
      reference.quote_no
  end
end
