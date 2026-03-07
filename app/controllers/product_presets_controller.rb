class ProductPresetsController < ApplicationController
  def index
    @spec_presets = current_user.company.spec_presets.ordered
    @addon_presets = current_user.company.addon_presets.ordered
  end
end
