class CompanyProfileImportsController < ApplicationController
  before_action :require_company_settings_manager!
  before_action :set_profile_import, only: %i[show update apply]

  def new
    @profile_import = current_user.company.company_profile_imports.new
  end

  def create
    @profile_import = current_user.company.company_profile_imports.new(profile_import_params.merge(created_by: current_user))
    @profile_import.source_file.attach(params.dig(:company_profile_import, :source_file)) if params.dig(:company_profile_import, :source_file).present?
    @profile_import.save!
    source = CompanyProfileSourceReader.new(@profile_import).call
    raise StructuredAiClient::ResponseError, t("self_service.company_import.errors.no_readable_text") if source.blank?

    result = CompanyProfileAiExtractor.new(@profile_import).call(source)
    @profile_import.update!(candidate_data: result, warnings: result["warnings"], status: "review")
    redirect_to @profile_import
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  rescue StructuredAiClient::ConfigurationError, StructuredAiClient::ResponseError => error
    @profile_import&.update!(status: "failed", warnings: Array(@profile_import.warnings) + [ error.message ]) if @profile_import&.persisted?
    redirect_to(@profile_import&.persisted? ? company_profile_import_path(@profile_import) : new_company_profile_import_path,
      alert: t("self_service.company_import.flash.analysis_failed"))
  end

  def show; end

  def update
    @profile_import.update!(candidate_data: reviewed_candidate_data, status: "review")
    redirect_to @profile_import, notice: t("self_service.company_import.flash.review_saved")
  end

  def apply
    @profile_import.update!(candidate_data: reviewed_candidate_data)
    current_user.company.update!(company_attributes)
    @profile_import.update!(status: "applied")
    redirect_to edit_company_settings_path, notice: t("self_service.company_import.flash.applied")
  end

  private

  def set_profile_import
    @profile_import = current_user.company.company_profile_imports.find(params[:id])
  end

  def profile_import_params
    params.require(:company_profile_import).permit(:source_text)
  end

  def reviewed_candidate_data
    existing = @profile_import.candidate_data
    fields = params.fetch(:company_profile_import, {}).fetch(:candidate_data, {}).permit(*CompanyProfileImport::COMPANY_FIELDS).to_h
    existing.merge("company" => existing.fetch("company", {}).merge(fields))
  end

  def company_attributes
    reviewed_candidate_data.fetch("company", {}).slice(*CompanyProfileImport::COMPANY_FIELDS).compact_blank
  end
end
