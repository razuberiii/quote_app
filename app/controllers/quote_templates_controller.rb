class QuoteTemplatesController < ApplicationController
  def edit
    @quote_template = current_user.company.quote_template_or_default
  end

  def update
    @quote_template = current_user.company.quote_template_or_default
    current_user.company.update!(company_params)
    current_user.company.logo.attach(params[:company_logo]) if params[:company_logo].present?

    if @quote_template.update(quote_template_params)
      redirect_to edit_quote_template_path, notice: "Quote template updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def quote_template_params
    params.require(:quote_template).permit(
      :show_payment_term,
      :show_valid_until,
      :show_notes,
      :show_logo,
      :show_negotiated_flag,
      :show_currency,
      :show_product_images,
      :show_terms_section,
      :show_signature_block
    )
  end

  def company_params
    params.fetch(:company, {}).permit(:name, :address, :phone, :email, :website)
  end
end
