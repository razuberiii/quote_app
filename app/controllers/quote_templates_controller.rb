class QuoteTemplatesController < ApplicationController
  before_action :require_company_template_manager!
  before_action :set_quote_template, only: %i[edit update destroy set_default]

  def index
    @quote_templates = current_user.company.quote_templates.ordered
    @template_usage_counts = current_user.company.quotes.not_archived.where(template_id: @quote_templates.select(:id)).group(:template_id).count
  end

  def new
    @quote_template = current_user.company.quote_templates.new(default_template_values)
  end

  def create
    @quote_template = current_user.company.quote_templates.new(quote_template_params)
    purge_watermark_image!(@quote_template) if remove_watermark_image_requested?
    purge_signature_image!(@quote_template) if remove_signature_image_requested?

    if @quote_template.save
      if params[:make_default] == "1" || current_user.company.quote_templates.count == 1
        apply_default_template!(@quote_template)
      end
      redirect_to quote_templates_path, notice: "Template created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    purge_watermark_image!(@quote_template) if remove_watermark_image_requested?
    purge_signature_image!(@quote_template) if remove_signature_image_requested?

    if @quote_template.update(quote_template_params)
      apply_default_template!(@quote_template) if params[:make_default] == "1"
      redirect_to quote_templates_path, notice: "Template updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quote_template.destroy
    current_user.company.ensure_default_template!
    redirect_to quote_templates_path, notice: "Template deleted"
  end

  def set_default
    apply_default_template!(@quote_template)
    redirect_to quote_templates_path, notice: "Default template updated"
  end

  private

  def set_quote_template
    @quote_template = current_user.company.quote_templates.find(params[:id])
  end

  def quote_template_params
    params.require(:quote_template).permit(
      :name,
      :slug,
      :layout_type,
      :layout_density,
      :accent_color,
      :font_family,
      :amount_decimals,
      :thousand_separator,
      :currency_display_mode,
      :logo_position,
      :description_label,
      :spec_label,
      :addon_label,
      :qty_label,
      :unit_price_label,
      :line_total_label,
      :footer_text,
      :show_logo,
      :show_images,
      :show_tax,
      :show_shipping,
      :show_closing_message,
      :show_saas_branding,
      :excel_show_grid_lines,
      :closing_message,
      :show_currency,
      :show_valid_until,
      :show_customer_owner,
      :show_payment_term,
      :show_terms_section,
      :show_notes,
      :show_signature_block,
      :signature_name,
      :signature_image,
      :show_watermark,
      :watermark_text,
      :watermark_opacity,
      :watermark_image,
      :document_kind,
      :quotation_title,
      :quotation_number_label,
      :quotation_footer_note,
      :pi_title,
      :pi_number_label,
      :pi_footer_note
    )
  end

  def remove_watermark_image_requested?
    params.dig(:quote_template, :remove_watermark_image).to_s == "1"
  end

  def purge_watermark_image!(template)
    return unless template.watermark_image.attached?

    template.watermark_image.purge
  end

  def remove_signature_image_requested?
    params.dig(:quote_template, :remove_signature_image).to_s == "1"
  end

  def purge_signature_image!(template)
    return unless template.signature_image.attached?

    template.signature_image.purge
  end

  def default_template_values
    {
      layout_type: :classic,
      layout_density: "standard",
      accent_color: "#1F4E79",
      font_family: "Noto Sans",
      amount_decimals: 2,
      thousand_separator: "comma",
      currency_display_mode: "symbol_prefix",
      logo_position: "right",
      description_label: "Description",
      spec_label: "Spec",
      addon_label: "Add-on",
      qty_label: "Qty",
      unit_price_label: "Unit Price",
      line_total_label: "Line Total",
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
      show_customer_owner: true,
      show_payment_term: true,
      show_terms_section: true,
      show_notes: true,
      show_watermark: false,
      watermark_text: "",
      watermark_opacity: 12
    }
  end

  def apply_default_template!(new_default)
    company = current_user.company
    old_default_ids = company.quote_templates.where(default_template: true).where.not(id: new_default.id).pluck(:id)

    new_default.make_default!
    return if old_default_ids.empty?

    # Keep existing quote-template behavior intuitive: quotes on old default move to the new default.
    company.quotes.where(template_id: old_default_ids).update_all(template_id: new_default.id)
  end
end
