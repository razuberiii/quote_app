class CompanySettingsController < ApplicationController
  before_action :require_company_settings_manager!
  before_action :set_company

  def edit
    @template = @company.quote_template_or_default
  end

  def update
    @template = @company.quote_template_or_default
    remove_logo_requested = company_settings_params[:remove_logo].to_s == "1"

    Company.transaction do
      @company.logo.purge if remove_logo_requested && @company.logo.attached?
      @company.update!(company_attrs)
      @template.update!(template_attrs) if template_attrs.present?
    end

    redirect_to edit_company_settings_path, notice: "Company settings updated."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Please check the highlighted fields."
    render :edit, status: :unprocessable_entity
  end

  private

  def set_company
    @company = current_user.company
  end

  def company_settings_params
    @company_settings_params ||= params.require(:company).permit(
      :name,
      :legal_name,
      :registration_number,
      :registration_details,
      :email,
      :phone,
      :address,
      :website,
      :default_currency,
      :default_trade_term,
      :default_payment_term,
      :default_tax_rate,
      :default_validity_days,
      :brand_color,
      :logo,
      :remove_logo,
      :template_show_logo,
      :template_show_images,
      :template_show_terms_section,
      :template_show_notes,
      :template_show_payment_term,
      :template_show_customer_owner
    )
  end

  def company_attrs
    company_settings_params.except(
      :remove_logo,
      :template_show_logo,
      :template_show_images,
      :template_show_terms_section,
      :template_show_notes,
      :template_show_payment_term,
      :template_show_customer_owner
    )
  end

  def template_attrs
    attrs = {}
    if company_settings_params[:brand_color].present? && follow_brand_for_template?
      attrs[:accent_color] = company_settings_params[:brand_color]
    end
    attrs[:show_logo] = ActiveModel::Type::Boolean.new.cast(company_settings_params[:template_show_logo]) if company_settings_params.key?(:template_show_logo)
    attrs[:show_images] = ActiveModel::Type::Boolean.new.cast(company_settings_params[:template_show_images]) if company_settings_params.key?(:template_show_images)
    attrs[:show_terms_section] = ActiveModel::Type::Boolean.new.cast(company_settings_params[:template_show_terms_section]) if company_settings_params.key?(:template_show_terms_section)
    attrs[:show_notes] = ActiveModel::Type::Boolean.new.cast(company_settings_params[:template_show_notes]) if company_settings_params.key?(:template_show_notes)
    attrs[:show_payment_term] = ActiveModel::Type::Boolean.new.cast(company_settings_params[:template_show_payment_term]) if company_settings_params.key?(:template_show_payment_term)
    attrs[:show_customer_owner] = ActiveModel::Type::Boolean.new.cast(company_settings_params[:template_show_customer_owner]) if company_settings_params.key?(:template_show_customer_owner)
    attrs
  end

  def follow_brand_for_template?
    @template.accent_color.blank? || @template.accent_color.casecmp("#1F4E79").zero?
  end
end
