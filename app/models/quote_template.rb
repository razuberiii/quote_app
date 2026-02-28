class QuoteTemplate < ApplicationRecord
  belongs_to :company
  has_many :quotes, foreign_key: :template_id, dependent: :nullify

  enum :layout_type, { classic: "classic", modern: "modern", industry: "industry" }, validate: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :company_id }
  validates :accent_color,
            format: {
              with: /\A#(?:\h{3}|\h{6})\z/,
              message: "must be a valid HEX color like #1F4E79"
            }
  validates :font_family, presence: true

  validates :document_kind, inclusion: { in: %w[quotation proforma_invoice] }

  BOOLEAN_FIELDS = %i[
    show_payment_term
    show_valid_until
    show_notes
    show_logo
    show_negotiated_flag
    show_currency
    show_product_images
    show_terms_section
    show_signature_block
    show_images
    show_tax
    show_shipping
    excel_show_grid_lines
    default_template
  ].freeze

  BOOLEAN_FIELDS.each do |field|
    validates field, inclusion: { in: [ true, false ] }
  end

  before_validation :normalize_slug
  before_validation :sync_legacy_fields
  before_validation :set_defaults

  scope :ordered, -> { order(default_template: :desc, created_at: :asc) }

  def show_images?
    show_images.nil? ? show_product_images : show_images
  end

  def show_product_images?
    show_images?
  end

  def resolved_document_title(kind = default_document_kind)
    if kind == "pi"
      pi_title.presence || document_title.presence || "PROFORMA INVOICE"
    else
      quotation_title.presence || document_title.presence || "QUOTATION"
    end
  end

  def resolved_document_number_label(kind = default_document_kind)
    if kind == "pi"
      pi_number_label.presence || document_number_label.presence || "PI #"
    else
      quotation_number_label.presence || document_number_label.presence || "Quote #"
    end
  end

  def resolved_footer_note(kind = default_document_kind)
    if kind == "pi"
      pi_footer_note.presence || footer_text.presence || footer_note
    else
      quotation_footer_note.presence || footer_text.presence || footer_note
    end
  end

  def normalize_document_kind(kind)
    case kind.to_s
    when "pi", "proforma_invoice" then "pi"
    else "quote"
    end
  end

  def default_document_kind
    normalize_document_kind(document_kind == "proforma_invoice" ? "pi" : "quote")
  end

  def make_default!
    transaction do
      company.quote_templates.where(default_template: true).where.not(id: id).update_all(default_template: false)
      update!(default_template: true)
    end
  end

  private

  def normalize_slug
    base = slug.presence || name
    self.slug = base.to_s.parameterize if base.present?
  end

  def sync_legacy_fields
    self.show_product_images = show_images if has_attribute?(:show_product_images)
    self.show_images = show_product_images if show_images.nil?
    self.footer_note = footer_text if footer_text.present? && footer_note.blank?
    self.footer_text = footer_note if footer_text.blank? && footer_note.present?
  end

  def set_defaults
    self.name = "Template" if name.blank?
    self.layout_type ||= "classic"
    self.accent_color = "#1F4E79" if accent_color.blank?
    self.font_family = "Noto Sans" if font_family.blank?
    self.footer_text ||= ""
    self.show_images = true if show_images.nil?
    self.show_tax = true if show_tax.nil?
    self.show_shipping = true if show_shipping.nil?
    self.excel_show_grid_lines = false if excel_show_grid_lines.nil?
  end
end
