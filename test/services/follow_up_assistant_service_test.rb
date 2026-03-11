require "test_helper"

class FollowUpAssistantServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    @customer = customers(:one)
    @customer.update!(name: "Acme", contact_name: "Mia", status: "new", customer_level: "normal")
    @transient_customer = Customer.new(company: @company, name: "Acme", contact_name: "Mia", status: "new", customer_level: "normal")
  end

  test "returns not viewed message for sent unviewed quote" do
    quote = Quote.new(company: @company, customer: @transient_customer, status: "sent", sent_at: Time.current)

    message = FollowUpAssistantService.new(customer: @transient_customer, latest_quote: quote).call

    assert_equal I18n.t("follow_up.assistant.messages.not_viewed", name: "Mia"), message
  end

  test "returns viewed message for viewed quote" do
    quote = Quote.new(company: @company, customer: @transient_customer, status: "viewed", viewed_at: Time.current)

    message = FollowUpAssistantService.new(customer: @transient_customer, latest_quote: quote, quote_view_status: "viewed").call

    assert_equal I18n.t("follow_up.assistant.messages.viewed", name: "Mia"), message
  end

  test "returns expired message for expired quote" do
    quote = Quote.new(company: @company, customer: @transient_customer, status: "expired")

    message = FollowUpAssistantService.new(customer: @transient_customer, latest_quote: quote, quote_expiry_status: "expired").call

    assert_equal I18n.t("follow_up.assistant.messages.expired", name: "Mia"), message
  end

  test "appends share link when relevant quote has active public share" do
    customer = create_customer
    quote = create_quote_with_item(status: "sent")
    quote.update!(customer: customer)
    share = QuoteShare.create!(
      company: @company,
      quote: quote,
      token: SecureRandom.hex(12),
      snapshot: { "quote_no" => quote.quote_no }
    )

    message = FollowUpAssistantService.new(
      customer: customer,
      latest_quote: quote,
      quote_view_status: "not_viewed",
      locale: :en,
      url_options: { host: "example.com", protocol: "https" }
    ).call

    assert_includes message, I18n.t("follow_up.message.quote_link_intro")
    assert_includes message, I18n.t("follow_up.message.quote_link_label")
    assert_includes message, share.token
  end

  test "uses latest revision share link for same quote number" do
    customer = create_customer
    quote_v1 = create_quote_with_item(status: "expired")
    quote_v1.update!(customer: customer)
    quote_v2 = quote_v1.build_revision
    quote_v2.status = "expired"
    quote_v2.valid_until ||= Date.current + 7.days
    quote_v2.save!

    share_v1 = QuoteShare.create!(
      company: @company,
      quote: quote_v1,
      token: SecureRandom.hex(12),
      snapshot: { "quote_no" => quote_v1.quote_no }
    )
    share_v2 = QuoteShare.create!(
      company: @company,
      quote: quote_v2,
      token: SecureRandom.hex(12),
      snapshot: { "quote_no" => quote_v2.quote_no }
    )

    message = FollowUpAssistantService.new(
      customer: customer,
      locale: :en,
      url_options: { host: "example.com", protocol: "https" }
    ).call

    assert_includes message, share_v2.token
    refute_includes message, share_v1.token
  end

  test "uses quote template webview locale for suggested message when locale is not explicit" do
    customer = create_customer
    template = quote_templates(:one)
    template.update!(webview_locale: "zh-CN")

    quote = create_quote_with_item(status: "sent")
    quote.update!(customer: customer, template: template, sent_at: Time.current)

    previous_locale = I18n.locale
    I18n.locale = :en

    message = FollowUpAssistantService.new(customer: customer, latest_quote: quote).call

    assert_equal I18n.t("follow_up.assistant.messages.not_viewed", locale: :"zh-CN", name: "Mia"), message
  ensure
    I18n.locale = previous_locale
  end

  private

  def create_quote_with_item(status: "draft")
    Quote.create!(
      company: @company,
      customer: @customer,
      currency: "USD",
      status: status,
      valid_until: Date.current + 7.days,
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: "Sample item",
          unit_price: 100,
          quantity: 1
        }
      ]
    )
  end

  def create_customer
    Customer.create!(
      company: @company,
      name: "Link Test Customer",
      contact_name: "Mia",
      status: "new",
      customer_level: "normal"
    )
  end
end
