class BillingController < ApplicationController
  before_action :authenticate_user!

  def checkout
    price_id = { "solo" => ENV["STRIPE_SOLO_PRICE_ID"], "pro" => ENV["STRIPE_PRO_PRICE_ID"], "business" => ENV["STRIPE_BUSINESS_PRICE_ID"] }.fetch(params.require(:plan))
    raise "Stripe is not configured" if ENV["STRIPE_SECRET_KEY"].blank? || price_id.blank?
    Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
    session = Stripe::Checkout::Session.create(mode: "subscription", customer_email: current_user.email,
      line_items: [{ price: price_id, quantity: 1 }], client_reference_id: current_user.company_id,
      metadata: { plan: params[:plan] }, subscription_data: { metadata: { plan: params[:plan] } },
      success_url: pricing_url(checkout: "success"), cancel_url: pricing_url(checkout: "cancelled"))
    redirect_to session.url, allow_other_host: true
  rescue KeyError, StandardError => error
    redirect_to pricing_path, alert: error.message
  end

  def portal
    raise "Stripe is not configured" if ENV["STRIPE_SECRET_KEY"].blank? || current_user.company.stripe_customer_id.blank?
    Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
    session = Stripe::BillingPortal::Session.create(customer: current_user.company.stripe_customer_id, return_url: edit_company_settings_url)
    redirect_to session.url, allow_other_host: true
  rescue StandardError => error
    redirect_to edit_company_settings_path, alert: error.message
  end
end
