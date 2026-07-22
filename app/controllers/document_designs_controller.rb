class DocumentDesignsController < ApplicationController
  before_action :require_company_template_manager!

  def edit
    @design = current_user.company.quote_template_or_default
  end

  def update
    @design = current_user.company.quote_template_or_default
    if @design.update(design_params)
      redirect_to edit_document_design_path, notice: t("document_design.flash.saved")
    else
      flash.now[:alert] = @design.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def design_params
    params.require(:quote_template).permit(
      :layout_type, :layout_density, :accent_color, :font_family, :logo_position,
      :show_logo, :show_images, :show_tax, :show_shipping, :show_payment_term,
      :show_valid_until, :show_terms_section, :show_notes, :show_scope_of_supply,
      :show_signature_block, :show_closing_message, :closing_message,
      :webview_locale, :public_link_locale, :pdf_locale, :excel_locale,
      :amount_decimals, :thousand_separator, :currency_display_mode
    )
  end
end
