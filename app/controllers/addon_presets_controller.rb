class AddonPresetsController < ApplicationController
  before_action :set_addon_preset, only: %i[edit update destroy]

  def index
    @addon_presets = current_user.company.addon_presets.ordered
    @addon_preset = current_user.company.addon_presets.new
  end

  def create
    @addon_preset = current_user.company.addon_presets.new(addon_preset_params)
    if @addon_preset.save
      redirect_to addon_presets_path, notice: "Add-on preset created."
    else
      @addon_presets = current_user.company.addon_presets.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @addon_preset.update(addon_preset_params)
      redirect_to addon_presets_path, notice: "Add-on preset updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @addon_preset.destroy
    redirect_to addon_presets_path, notice: "Add-on preset deleted."
  end

  private

  def set_addon_preset
    @addon_preset = current_user.company.addon_presets.find(params[:id])
  end

  def addon_preset_params
    params.require(:addon_preset).permit(:name, :entries_text)
  end
end
