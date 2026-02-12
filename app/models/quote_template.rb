class QuoteTemplate < ApplicationRecord
  belongs_to :company

  validates :show_payment_term, inclusion: { in: [ true, false ] }
  validates :show_valid_until, inclusion: { in: [ true, false ] }
  validates :show_notes, inclusion: { in: [ true, false ] }
  validates :show_logo, inclusion: { in: [ true, false ] }
  validates :show_negotiated_flag, inclusion: { in: [ true, false ] }
  validates :show_currency, inclusion: { in: [ true, false ] }
  validates :show_product_images, inclusion: { in: [ true, false ] }
  validates :show_terms_section, inclusion: { in: [ true, false ] }
  validates :show_signature_block, inclusion: { in: [ true, false ] }
end
