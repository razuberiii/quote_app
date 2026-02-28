class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :quote_shares, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :quote_templates, dependent: :destroy
  has_one_attached :logo

  after_create :ensure_quote_template!

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
      show_logo: true,
      show_images: true,
      show_tax: true,
      show_shipping: true,
      excel_show_grid_lines: false,
      show_currency: true,
      show_valid_until: true,
      show_notes: true,
      show_terms_section: true,
      accent_color: "#1F4E79",
      font_family: "Noto Sans",
      footer_text: ""
    }
  end
end
