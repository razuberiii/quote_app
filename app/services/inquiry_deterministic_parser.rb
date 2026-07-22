class InquiryDeterministicParser
  EMAIL = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
  INCOTERM = /\b(EXW|FCA|FOB|CFR|CIF|CPT|CIP|DAP|DPU|DDP)\b/i
  CURRENCY = /\b(USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\b/i
  QUANTITY = /\b(\d[\d,]*(?:\.\d+)?)\s*(pcs?|pieces?|sets?|units?|kg|tons?|boxes?)\b/i
  NUMBERED_PRODUCT = /^\s*\d+[.)]\s*(\d[\d,]*(?:\.\d+)?)\s+(.+)$/i
  MODEL = /\bmodel\s*[:#-]?\s*([A-Z0-9][A-Z0-9._\/-]*)/i
  VOLTAGE = /\b(\d{2,4}\s*V(?:\s*(?:\/|,)?\s*\d{2,3}\s*Hz)?)\b/i

  def initialize(text) = @text = text.to_s

  def call
    match = @text.match(QUANTITY)
    { "customer" => customer_candidate, "contact_name" => contact_candidate,
      "contact_email" => @text[EMAIL], "currency" => @text[CURRENCY]&.upcase,
      "incoterm" => @text.match(INCOTERM)&.[](1)&.upcase,
      "destination" => destination_candidate,
      "products" => product_candidates,
      "quantity_candidate" => (match && { "value" => match[1].delete(",").to_f, "unit" => match[2], "excerpt" => match[0] }) }.compact
  end

  private

  def product_candidates
    numbered = @text.lines.filter_map do |line|
      match = line.match(NUMBERED_PRODUCT)
      next unless match
      description = match[2].sub(/[,.]?\s*model\b.*$/i, "").strip
      {
        "name" => description.presence || match[2].strip,
        "model" => match[2].match(MODEL)&.[](1),
        "quantity" => match[1].delete(",").to_f,
        "unit" => "pcs",
        "specifications" => { "voltage" => match[2].match(VOLTAGE)&.[](1) }.compact,
        "evidence" => line.strip, "confidence" => 0.74,
        "catalog_product_id" => nil, "unit_price" => nil, "price_source" => nil
      }
    end
    return numbered if numbered.any?

    quantity = @text.match(QUANTITY)
    model = @text.match(MODEL)
    return [] unless quantity && model

    [{
      "name" => model[1], "model" => model[1], "quantity" => quantity[1].delete(",").to_f,
      "unit" => quantity[2], "specifications" => { "voltage" => @text.match(VOLTAGE)&.[](1) }.compact,
      "evidence" => @text.lines.find { |line| line.include?(quantity[0]) }.to_s.strip,
      "confidence" => 0.62, "catalog_product_id" => nil, "unit_price" => nil, "price_source" => nil
    }]
  end

  def signature_parts
    lines = @text.lines.map(&:strip)
    closing = lines.index { |value| value.match?(/\A(?:regards|best wishes|sincerely)[,:\s]*\z/i) }
    if closing
      return lines[(closing + 1)..].take_while { |value| !value.start_with?("[") }
        .reject(&:blank?).reject { |value| value.match?(EMAIL) }
    end

    line = lines.reverse.find { |value| value.match?(EMAIL) || value.match?(/regards|best wishes|sincerely/i) }
    line.to_s.sub(EMAIL, "").sub(/.*?(regards|best wishes|sincerely)[,:\s]*/i, "").split(",").map(&:strip).reject(&:blank?)
  end

  def customer_candidate = signature_parts.last
  def contact_candidate = signature_parts.length > 1 ? signature_parts.first : nil

  def destination_candidate
    @text.match(/\b(?:CIF|CFR|CPT|CIP|DAP|DPU|DDP)\s+([^\n,.;]+)/i)&.[](1)&.strip&.sub(/\s+for:?\z/i, "")&.sub(/\s+in\s+(?:USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\z/i, "")
  end
end
