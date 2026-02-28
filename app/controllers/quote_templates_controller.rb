class QuoteTemplatesController < ApplicationController
  before_action :set_quote_template, only: %i[edit update destroy set_default]

  def index
    @quote_templates = current_user.company.quote_templates.ordered
  end

  def new
    @quote_template = current_user.company.quote_templates.new(default_template_values)
  end

  def create
    @quote_template = current_user.company.quote_templates.new(quote_template_params)

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
      :qty_label,
      :unit_price_label,
      :line_total_label,
      :footer_text,
      :show_logo,
      :show_images,
      :show_tax,
      :show_shipping,
      :excel_show_grid_lines,
      :show_currency,
      :show_valid_until,
      :show_payment_term,
      :show_terms_section,
      :show_notes,
      :show_signature_block,
      :document_kind,
      :quotation_title,
      :quotation_number_label,
      :quotation_footer_note,
      :pi_title,
      :pi_number_label,
      :pi_footer_note
    )
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
      qty_label: "Qty",
      unit_price_label: "Unit Price",
      line_total_label: "Line Total",
      show_logo: true,
      show_images: true,
      show_tax: true,
      show_shipping: true,
      excel_show_grid_lines: false,
      show_currency: true,
      show_valid_until: true,
      show_payment_term: true,
      show_terms_section: true,
      show_notes: true
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
