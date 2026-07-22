class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update]

  def index
    @customers = current_user.company.customers.search(params[:q]).includes(:quotes).order(updated_at: :desc)
  end

  def show
    @quotes = @customer.quotes.not_archived.order(updated_at: :desc)
  end

  def new
    @customer = current_user.company.customers.new
  end

  def create
    @customer = current_user.company.customers.new(customer_params)
    if @customer.save
      redirect_to customer_path(@customer), notice: t("customers.core.saved")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @customer.update(customer_params)
      redirect_to customer_path(@customer), notice: t("customers.core.saved")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :legal_name, :contact_name, :email, :phone,
      :country, :address, :tax_id, :tax_id_type, :payment_terms, :notes)
  end
end
