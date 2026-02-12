class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

  def index
    @products = current_user.company.products.order(:name)
    @search_query = params[:query]
    @products = @products.where("name ILIKE ?", "%#{@search_query}%") if @search_query.present?
  end

  def show
  end

  def new
    @product = current_user.company.products.new
  end

  def create
    @product = current_user.company.products.new(product_params)

    if @product.save
      redirect_to @product, notice: "Product created successfully"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "Product updated successfully"
    else
      render :edit
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: "Product deleted successfully"
  end

  private

  def set_product
    @product = current_user.company.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :sku, :description, :default_price, :image)
  end
end
