class SpecPresetsController < ApplicationController
  before_action :set_spec_preset, only: %i[edit update destroy]

  def index
    @spec_presets = current_user.company.spec_presets.ordered
    @spec_preset = current_user.company.spec_presets.new
  end

  def create
    @spec_preset = current_user.company.spec_presets.new(spec_preset_params)
    if @spec_preset.save
      redirect_to spec_presets_path, notice: "Spec preset created."
    else
      @spec_presets = current_user.company.spec_presets.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @spec_preset.update(spec_preset_params)
      redirect_to spec_presets_path, notice: "Spec preset updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @spec_preset.destroy
    redirect_to spec_presets_path, notice: "Spec preset deleted."
  end

  private

  def set_spec_preset
    @spec_preset = current_user.company.spec_presets.find(params[:id])
  end

  def spec_preset_params
    params.require(:spec_preset).permit(:name, :entries_text)
  end
end
