class InquiryDeterministicParser
  EMAIL = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
  INCOTERM = /\b(EXW|FCA|FOB|CFR|CIF|CPT|CIP|DAP|DPU|DDP)\b/i
  CURRENCY = /\b(USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\b/i
  QUANTITY = /\b(\d[\d,]*(?:\.\d+)?)\s*(pcs?|pieces?|sets?|units?|kg|tons?|boxes?)\b/i

  def initialize(text) = @text = text.to_s

  def call
    match = @text.match(QUANTITY)
    { "contact_email" => @text[EMAIL], "currency" => @text[CURRENCY]&.upcase,
      "incoterm" => @text.match(INCOTERM)&.[](1)&.upcase,
      "quantity_candidate" => (match && { "value" => match[1].delete(",").to_f, "unit" => match[2], "excerpt" => match[0] }) }.compact
  end
end
