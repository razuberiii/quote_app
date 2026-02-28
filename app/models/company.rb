class Company < ApplicationRecord
  validates :name, presence: true
  validates :brand_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validates :default_validity_days, numericality: { greater_than: 0 }, allow_nil: true
  validates :default_tax_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :quote_shares, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :quote_templates, dependent: :destroy
  has_many :team_invitations, dependent: :destroy
  has_one_attached :logo

  after_create :ensure_quote_template!
  before_validation :apply_default_settings

  def default_quote_template
    quote_templates.find_by(default_template: true)
  end

  def quote_template
    default_quote_template
  end

  def quote_template_or_default
    default_quote_template || quote_templates.order(:created_at).first || build_default_template
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
      excel_show_grid_lines: false,
      show_currency: true,
      show_valid_until: true,
      show_notes: true,
      show_terms_section: true,
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
end
