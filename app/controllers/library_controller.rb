class LibraryController < ApplicationController
  def index
    @section = params[:section].presence_in(%w[products presets]) || "products"
    @products = current_user.company.products.order(updated_at: :desc).limit(24)
    @quote_presets = current_user.company.quote_presets.order(updated_at: :desc).limit(12)
  end
end
