class LandingController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_marketing", only: [ :index, :demo, :sample_quote, :contact ]
  before_action :set_public_paths
  before_action :set_seo_page, only: [ :index, :demo, :sample_quote, :contact ]

  def index
  end

  def demo; end

  def contact; end

  def sample_quote
    @sample_quote = {
      document_title: "PROFORMA INVOICE",
      quote_no: "PI-2026-0240",
      issued_on: Date.current.strftime("%Y-%m-%d"),
      valid_until: (Date.current + 30.days).strftime("%Y-%m-%d"),
      currency: "USD",
      seller: {
        name: "Atlas Industrial Supply Co.",
        address: "88 Harbor Industry Road, Qingdao, China",
        phone: "+86 532 5558 9001",
        email: "sales@atlasindustrial.com",
        website: "www.atlasindustrial.com"
      },
      buyer: {
        name: "Pacific Trading Group",
        contact_name: "Ethan Miller",
        address: "1458 Bay Logistics Ave, Long Beach, CA, USA",
        phone: "+1 562 555 0187",
        email: "procurement@pacifictrading.com"
      },
      items: [
        {
          description: "Industrial Hydraulic Pump Model HZ-240",
          quantity: 5,
          unit_price: 480.0
        }
      ],
      terms: {
        payment: "30% advance, 70% before shipment",
        validity: "This quotation is valid for 30 days from issue date.",
        delivery: "Lead time: 20 working days after advance payment.",
        notes: "Packing: Export plywood case. Port of loading: Qingdao."
      }
    }
  end

  private

  def set_seo_page
    page_key = {
      "index" => :homepage,
      "demo" => :demo,
      "contact" => :contact,
      "sample_quote" => :sample_quote
    }.fetch(action_name)

    @seo_page = SeoPageRegistry.fetch(page_key)
  end

  def set_public_paths
    @contact_request ||= ContactRequest.new
    @contact_email = ContactMailer.contact_email_for_environment
    @demo_path = demo_path
    @sample_quote_path = sample_quote_path
    @resources_path = resources_path
  end
end
