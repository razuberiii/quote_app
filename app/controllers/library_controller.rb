class LibraryController < ApplicationController
  def index
    @section = params[:section].presence_in(%w[products pricing presets content formats brand output]) || "products"
    @products = current_user.company.products.order(updated_at: :desc).limit(24)
    @quote_presets = current_user.company.quote_presets.order(updated_at: :desc).limit(12)
    @templates = current_user.company.quote_templates.order(updated_at: :desc).limit(12)
  end
end
