class QuotePresetsController < ApplicationController
  before_action :require_company_template_manager!
  before_action :set_quote_preset, only: %i[edit update destroy duplicate]

  def index
    @active_module_key = active_module_key_param
    @quote_presets = current_user.company.quote_presets.ordered
    @module_presets = @quote_presets.select { |preset| preset.module_key == @active_module_key }
    @quote_preset_master = current_user.company.quote_preset_master || current_user.company.build_quote_preset_master
  end

  def new
    @active_module_key = active_module_key_param
    @quote_preset = current_user.company.quote_presets.new(module_key: @active_module_key)
  end

  def create
    @quote_preset = current_user.company.quote_presets.new(quote_preset_params)
    purge_seller_signature_image!(@quote_preset) if remove_seller_signature_image_requested?
    purge_seller_stamp_image!(@quote_preset) if remove_seller_stamp_image_requested?
    if @quote_preset.save
      redirect_to quote_presets_path(module_key: @quote_preset.module_key), notice: t("quote_presets.flash.created", default: "Quote preset created.")
    else
      @active_module_key = @quote_preset.module_key
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @active_module_key = @quote_preset.module_key
  end

  def update
    purge_seller_signature_image!(@quote_preset) if remove_seller_signature_image_requested?
    purge_seller_stamp_image!(@quote_preset) if remove_seller_stamp_image_requested?
    if @quote_preset.update(quote_preset_params)
      redirect_to quote_presets_path(module_key: @quote_preset.module_key), notice: t("quote_presets.flash.updated", default: "Quote preset updated.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    module_key = @quote_preset.module_key
    @quote_preset.destroy
    redirect_to quote_presets_path(module_key: module_key), notice: t("quote_presets.flash.deleted", default: "Quote preset deleted.")
  end

  def duplicate
    duplicate = @quote_preset.dup
    duplicate.name = @quote_preset.duplicated_name
    duplicate.seller_signature_image.attach(@quote_preset.seller_signature_image.blob) if @quote_preset.seller_signature_image.attached?
    duplicate.seller_stamp_image.attach(@quote_preset.seller_stamp_image.blob) if @quote_preset.seller_stamp_image.attached?
    if duplicate.save
      redirect_to quote_presets_path(module_key: duplicate.module_key), notice: t("quote_presets.flash.duplicated", default: "Quote preset duplicated.")
    else
      redirect_to quote_presets_path(module_key: @quote_preset.module_key), alert: duplicate.errors.full_messages.to_sentence
    end
  end

  private

  def set_quote_preset
    @quote_preset = current_user.company.quote_presets.find(params[:id])
  end

  def quote_preset_params
    params.require(:quote_preset).permit(
      :name,
      :module_key,
      :position,
      :seller_signature_image,
      :seller_stamp_image,
      payload: {}
    )
  end

  def remove_seller_signature_image_requested?
    params.dig(:quote_preset, :remove_seller_signature_image).to_s == "1"
  end

  def remove_seller_stamp_image_requested?
    params.dig(:quote_preset, :remove_seller_stamp_image).to_s == "1"
  end

  def active_module_key_param
    params[:module_key].presence_in(QuotePreset::MODULE_KEYS) || QuotePreset::MODULE_KEYS.first
  end

  def purge_seller_signature_image!(quote_preset)
    return unless quote_preset.seller_signature_image.attached?

    quote_preset.seller_signature_image.purge
  end

  def purge_seller_stamp_image!(quote_preset)
    return unless quote_preset.seller_stamp_image.attached?

    quote_preset.seller_stamp_image.purge
  end
end
