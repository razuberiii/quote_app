class QuoteReasonOptionsController < ApplicationController
  before_action :require_company_settings_manager!

  def create
    option = current_user.company.quote_reason_options.new(option_params)

    if option.save
      respond_to do |format|
        format.json do
          render json: {
            id: option.id,
            kind: option.kind,
            key: option.key,
            label: option.label
          }, status: :created
        end
        format.html { redirect_back fallback_location: edit_company_settings_path, notice: t("quote_reason_options.flash.created", default: "Reason option added.") }
      end
    else
      respond_to do |format|
        format.json { render json: { message: option.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: edit_company_settings_path, alert: option.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    option = current_user.company.quote_reason_options.find(params[:id])
    option.destroy!

    respond_to do |format|
      format.json { head :ok }
      format.html { redirect_back fallback_location: edit_company_settings_path, notice: t("quote_reason_options.flash.deleted", default: "Reason option deleted.") }
    end
  end

  private

  def option_params
    params.require(:quote_reason_option).permit(:kind, :label, :key, :position, :active)
  end
end
