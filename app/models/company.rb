class Company < ApplicationRecord
  DEFAULT_REMINDER_EMAIL_SUBJECT = "Reminder: %{quote_no} from %{company_name}".freeze
  DEFAULT_REMINDER_EMAIL_BODY = "This is a reminder that your quotation %{quote_no} from %{company_name} is still awaiting review.".freeze
  DEFAULT_REMINDER_EMAIL_CTA_LABEL = "Open quotation".freeze
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif image/svg+xml].freeze
  MAX_LOGO_SIZE = 5.megabytes

  validates :name, presence: true
  validates :brand_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validates :default_validity_days, numericality: { greater_than: 0 }, allow_nil: true
  validates :default_tax_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :quote_shares, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :spec_presets, dependent: :destroy
  has_many :addon_presets, dependent: :destroy
  has_many :quote_presets, dependent: :destroy
  has_one :quote_preset_master, dependent: :destroy
  has_many :quote_templates, dependent: :destroy
  has_many :quote_reason_options, dependent: :destroy
  has_many :company_documents, dependent: :destroy
  has_many :team_invitations, dependent: :destroy
  has_many :customer_tags, dependent: :destroy
  has_one_attached :logo
  validate :logo_constraints

  after_create :ensure_quote_template!
  after_create :ensure_quote_preset_samples!
  before_validation :apply_default_settings

  def default_quote_template
    quote_templates.find_by(default_template: true)
  end

  def quote_template
    default_quote_template
  end

  def quote_preset_limit_per_module
    users.where(
      "role = :admin_role OR (role = :vip_role AND (vip_expires_at IS NULL OR vip_expires_at > :now))",
      admin_role: User.roles[:admin],
      vip_role: User.roles[:vip],
      now: Time.current
    ).exists? ? 50 : 10
  end

  def quote_template_or_default
    default_quote_template || quote_templates.order(:created_at).first || build_default_template
  end

  def reminder_email_subject_for(quote:, customer:)
    interpolate_reminder_content(reminder_email_subject, DEFAULT_REMINDER_EMAIL_SUBJECT, quote:, customer:)
  end

  def reminder_email_body_for(quote:, customer:)
    interpolate_reminder_content(reminder_email_body, DEFAULT_REMINDER_EMAIL_BODY, quote:, customer:)
  end

  def reminder_email_cta_label_resolved
    reminder_email_cta_label.to_s.strip.presence || DEFAULT_REMINDER_EMAIL_CTA_LABEL
  end

  def ensure_default_template!
    return if quote_templates.where(default_template: true).exists?

    template = quote_templates.order(:created_at).first || quote_templates.create!(default_quote_template_attributes)
    template.update!(default_template: true) unless template.default_template?
  end

  private

  def ensure_quote_template!
    ensure_default_template!
  end

  def ensure_quote_preset_samples!
    QuotePresetSampleSeeder.seed_for!(self)
  end

  def build_default_template
    quote_templates.build(default_quote_template_attributes.merge(default_template: true))
  end

  def default_quote_template_attributes
    {
      name: "Default Template",
      slug: "default-template",
      layout_type: "classic",
      layout_density: "standard",
      show_logo: true,
      show_images: true,
      show_tax: true,
      show_shipping: true,
      show_closing_message: true,
      show_saas_branding: false,
      excel_show_grid_lines: false,
      closing_message: QuoteTemplate::DEFAULT_CLOSING_MESSAGE,
      show_currency: true,
      show_valid_until: true,
      show_notes: true,
      show_scope_of_supply: false,
      default_scope_of_supply_content: "",
      show_terms_section: true,
      show_customer_owner: true,
      amount_decimals: 2,
      thousand_separator: "comma",
      currency_display_mode: "symbol_prefix",
      logo_position: "right",
      description_label: "Description",
      qty_label: "Qty",
      unit_price_label: "Unit Price",
      line_total_label: "Line Total",
      accent_color: brand_color.presence || "#1F4E79",
      font_family: "Noto Sans",
      footer_text: ""
    }
  end

  def apply_default_settings
    self.default_currency = default_currency.presence || "USD"
    self.default_validity_days = 30 if default_validity_days.blank?
    self.default_tax_rate = 0 if default_tax_rate.blank?
    self.brand_color = brand_color.presence || "#1F4E79"
  end

  def interpolate_reminder_content(raw_value, fallback, quote:, customer:)
    template = raw_value.to_s.strip.presence || fallback
    template % {
      quote_no: quote.quote_no,
      company_name: name.to_s,
      customer_name: customer.contact_name.presence || customer.name.presence || "there"
    }
  rescue KeyError
    fallback % {
      quote_no: quote.quote_no,
      company_name: name.to_s,
      customer_name: customer.contact_name.presence || customer.name.presence || "there"
    }
  end

  def logo_constraints
    return unless logo.attached?

    if !LOGO_CONTENT_TYPES.include?(logo.blob.content_type)
      errors.add(:logo, "must be an image (PNG, JPG, WEBP, GIF, or SVG)")
    end
    if logo.blob.byte_size > MAX_LOGO_SIZE
      errors.add(:logo, "must be smaller than #{MAX_LOGO_SIZE / 1.megabyte}MB")
    end
  end
end
