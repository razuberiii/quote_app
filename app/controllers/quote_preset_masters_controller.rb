class QuotePresetMastersController < ApplicationController
  before_action :require_company_template_manager!

  def update
    master = current_user.company.quote_preset_master || current_user.company.build_quote_preset_master
    if master.update(quote_preset_master_params)
      redirect_to quote_presets_path, notice: t("quote_presets.flash.master_updated", default: "Master quote preset updated.")
    else
      redirect_to quote_presets_path, alert: master.errors.full_messages.to_sentence
    end
  end

  private

  def quote_preset_master_params
    params.require(:quote_preset_master).permit(
      :business_terms_preset_id,
      :advanced_trade_terms_preset_id,
      :advanced_logistics_preset_id,
      :container_loading_preset_id,
      :configuration_block_preset_id,
      :formal_closing_preset_id
    )
  end
end
