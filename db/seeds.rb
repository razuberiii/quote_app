# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

company = Company.find_or_create_by!(name: "Atlas Industrial Supply Co.") do |c|
  c.address = "88 Harbor Industry Road, Qingdao, China"
  c.phone = "+86 532 5558 9001"
  c.email = "sales@atlasindustrial.com"
  c.website = "www.atlasindustrial.com"
end

company.ensure_default_template!
company.default_quote_template&.update!(
  name: "Atlas Classic",
  slug: "atlas-classic",
  accent_color: "#1F4E79",
  font_family: "Noto Sans",
  layout_type: "classic",
  show_tax: true,
  show_shipping: true,
  show_terms_section: true,
  show_payment_term: true,
  default_template: true
)

customer = company.customers.find_or_create_by!(name: "Pacific Trading Group") do |c|
  c.contact_name = "Ethan Miller"
  c.address = "1458 Bay Logistics Ave, Long Beach, CA, USA"
  c.phone = "+1 562 555 0187"
  c.email = "procurement@pacifictrading.com"
  c.country = "United States"
  c.status = "active"
end

product = company.products.find_or_create_by!(sku: "HZ-240") do |p|
  p.name = "Industrial Hydraulic Pump Model HZ-240"
  p.default_price = 480.00
  p.description = "Industrial hydraulic pump for continuous-duty production lines."
end

quote = company.quotes.find_or_initialize_by(quote_no: "PI-2026-0240", customer: customer)
quote.assign_attributes(
  currency: "USD",
  issued_on: Date.current,
  valid_until: Date.current + 30.days,
  payment_term: "30% advance, 70% before shipment",
  status: "pending",
  tax_amount: 0,
  shipping_amount: 0,
  discount_amount: 0,
  terms_text: "Quotation validity: 30 days from issue date.",
  delivery_notes: "Lead time: 20 working days after advance payment.",
  legal_disclaimer: "Final shipment schedule is confirmed after receipt of advance payment.",
  template: company.quote_template_or_default
)

if quote.quote_items.blank?
  quote.quote_items.build(
    product: product,
    description: "Industrial Hydraulic Pump Model HZ-240",
    quantity: 5,
    unit_price: 480.00
  )
end

quote.save!

puts "Seeded demo data: #{company.name} / #{customer.name} / #{quote.quote_no}"
