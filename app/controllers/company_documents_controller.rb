class CompanyDocumentsController < ApplicationController
  before_action :require_company_settings_manager!
  before_action :set_company
  before_action :set_company_document, only: :destroy

  def create
    @company_document = @company.company_documents.new(company_document_params)

    if @company_document.save
      redirect_to edit_company_settings_path, notice: t("company_documents.flash.uploaded")
    else
      redirect_to edit_company_settings_path, alert: @company_document.errors.full_messages.to_sentence
    end
  end

  def destroy
    @company_document.destroy
    redirect_to edit_company_settings_path, notice: t("company_documents.flash.removed")
  end

  private

  def set_company
    @company = current_user.company
  end

  def set_company_document
    @company_document = @company.company_documents.find(params[:id])
  end

  def company_document_params
    params.require(:company_document).permit(:title, :document_type, :file)
  end
end
