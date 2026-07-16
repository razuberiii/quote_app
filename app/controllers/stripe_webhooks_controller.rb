class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    event = Stripe::Webhook.construct_event(request.raw_post, request.headers["Stripe-Signature"], ENV.fetch("STRIPE_WEBHOOK_SECRET"))
    record = SubscriptionEvent.find_or_initialize_by(provider_event_id: event.id)
    return head :ok if record.processed_at?

    object = event.data.object
    company = Company.find_by(stripe_customer_id: object.respond_to?(:customer) ? object.customer : nil)
    company ||= Company.find_by(id: object.respond_to?(:client_reference_id) ? object.client_reference_id : nil)
    return head :ok unless company

    record.assign_attributes(company: company, event_type: event.type, payload: event.to_hash)
    record.save!
    case event.type
    when "checkout.session.completed", "customer.subscription.updated"
      company.update!(stripe_customer_id: object.customer, stripe_subscription_id: object.subscription || object.id,
        subscription_status: "active", plan: plan_from_object(object))
    when "customer.subscription.deleted"
      company.update!(subscription_status: "cancelled")
    when "invoice.payment_failed"
      company.update!(subscription_status: "past_due")
    end
    record.update!(processed_at: Time.current)
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError, KeyError
    head :bad_request
  rescue ActiveRecord::RecordNotUnique
    head :ok
  end

  private

  def plan_from_object(object)
    price = object.respond_to?(:metadata) && object.metadata["plan"]
    price.presence_in(Company::PLANS) || "solo"
  end
end
