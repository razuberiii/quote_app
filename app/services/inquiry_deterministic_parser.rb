class InquiryDeterministicParser
  EMAIL = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
  INCOTERM = /\b(EXW|FCA|FOB|CFR|CIF|CPT|CIP|DAP|DPU|DDP)\b/i
  CURRENCY = /\b(USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\b/i
  UNIT = /pcs?|pieces?|sets?|units?|kg|tons?|boxes?|台|套|件|个|箱/i
  QUANTITY = /(\d[\d,]*(?:\.\d+)?)\s*(#{UNIT.source})(?=\s|[，。；、,.;:]|[^A-Za-z]|$)/i
  NUMBERED_PRODUCT = /^\s*\d+[.)]\s*(\d[\d,]*(?:\.\d+)?)\s+(.+)$/i
  MODEL = /(?:\bmodel|型号)\s*[:：#-]?\s*([A-Z0-9][A-Z0-9._\/-]*)/i
  VOLTAGE = /\b(\d{2,4}\s*V(?:\s*(?:\/|,)?\s*\d{2,3}\s*Hz)?)\b/i
  BUYER_HEADER = /^\s*(?:客户|买家)(?:[（(]([^）)]+)[）)])?\s*[：:]/i
  CUSTOMER_MESSAGE_HEADER = /^\[[^\n]*\brole=customer\b[^\n]*\bsender=([^\]|]+)[^\n]*\]$/i

  def initialize(text) = @text = text.to_s

  def call
    match = @text.match(QUANTITY)
    { "customer" => customer_candidate, "contact_name" => contact_candidate,
      "contact_email" => @text[EMAIL], "currency" => @text[CURRENCY]&.upcase,
      "incoterm" => @text.match(INCOTERM)&.[](1)&.upcase,
      "destination" => destination_candidate,
      "delivery" => delivery_candidate,
      "packing" => packing_candidate,
      "payment_terms" => payment_terms_candidate,
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
        "model" => match[2].match(MODEL)&.[](1)&.sub(/[.]+\z/, ""),
        "quantity" => match[1].delete(",").to_f,
        "unit" => "pcs",
        "specifications" => product_specifications(match[2]),
        "evidence" => line.strip, "confidence" => 0.74,
        "catalog_product_id" => nil, "unit_price" => nil, "price_source" => nil
      }
    end
    return numbered if numbered.any?

    quantity = @text.match(QUANTITY)
    model = @text.match(MODEL)
    return [] unless quantity && model

    description = @text.match(/#{Regexp.escape(quantity[0])}\s*([^，。；、,.;:\n]+?)(?=\s*[，,]?\s*(?:型号|model))/i)&.[](1)&.strip

    [ {
      "name" => description.presence || model[1], "model" => model[1].sub(/[.]+\z/, ""), "quantity" => quantity[1].delete(",").to_f,
      "unit" => quantity[2], "specifications" => product_specifications(@text),
      "evidence" => @text.lines.find { |line| line.include?(quantity[0]) }.to_s.strip,
      "confidence" => 0.62, "catalog_product_id" => nil, "unit_price" => nil, "price_source" => nil
    } ]
  end

  def product_specifications(source)
    { "voltage" => source.match(VOLTAGE)&.[](1),
      "配置要求" => requested_configuration_candidate }.compact
  end

  def requested_configuration_candidate
    @text.match(/(?:电源|电压)[^，,。；\\]{0,40}[，,]\s*(?:需要|要求)\s*([^，,。；\\]+?)(?=\s*(?:请报|报价|期望|希望|交付)|[，,。；\\]|$)/i)&.[](1)&.strip ||
      @text.match(/(?:please\s+)?include\s+([^\n.]+?)(?=\.\s*(?:quote|delivery)|[.\n]|$)/i)&.[](1)&.strip
  end

  def signature_parts
    if (sender = @text.lines.filter_map { |line| line.match(CUSTOMER_MESSAGE_HEADER)&.[](1)&.strip }.first)
      return [ sender, nil ]
    end

    if (header = buyer_header_parts)
      return [header[0], header[1]].compact
    end

    lines = @text.lines.map(&:strip)
    closing = lines.index { |value| value.match?(/\A(?:regards|best wishes|sincerely)[,:\s]*\z/i) }
    if closing
      return lines[(closing + 1)..].take_while { |value| !value.start_with?("[") }
        .reject(&:blank?).reject { |value| value.match?(EMAIL) }
    end

    line = lines.reverse.find { |value| value.match?(EMAIL) || value.match?(/regards|best wishes|sincerely/i) }
    line.to_s.sub(EMAIL, "").sub(/.*?(regards|best wishes|sincerely)[,:\s]*/i, "").split(",").map(&:strip).reject(&:blank?)
  end

  def buyer_header_parts
    details = @text.lines.filter_map { |line| line.match(BUYER_HEADER)&.[](1) }.first
    return unless details.present?

    parts = details.split(/\s*(?:\/|／|\||｜)\s*/, 2).map(&:strip).reject(&:blank?)
    parts.length > 1 ? parts : [parts.first, nil]
  end

  def customer_candidate = signature_parts.last
  def contact_candidate = signature_parts.length > 1 ? signature_parts.first : nil

  def destination_candidate
    @text.match(/\b(?:CIF|CFR|CPT|CIP|DAP|DPU|DDP)\s+([^\n,.;，。；]+)/i)&.[](1)&.strip&.sub(/\s+for:?\z/i, "")&.sub(/\s+in\s+(?:USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\z/i, "")
  end

  def delivery_candidate
    @text.match(/(?:期望|希望|要求)?\s*(\d+\s*(?:个)?(?:工作)?天内交付)/i)&.[](1)&.strip ||
      @text.match(/delivery\s+(?:within|in)\s+(\d+\s*(?:working\s+|business\s+)?days?)/i)&.[](1)&.then { |value| "#{value} delivery" if value }
  end

  def packing_candidate
    @text.match(/(?:包装(?:要求)?[：:]?\s*)?((?:出口)?(?:木箱|木架|纸箱|托盘)(?:包装)?)/i)&.[](1)&.strip ||
      @text.match(/((?:export\s+)?(?:plywood|wooden|carton)\s+(?:case|crate|box)(?:\s+packing)?)/i)&.[](1)&.strip
  end

  def payment_terms_candidate
    @text.match(/付款(?:条件|方式)?(?![？?])(?:希望|要求|为|是|[：:])\s*([^\\\n。；]+)/i)&.[](1)&.strip ||
      @text.match(/\bpayment\s+(?!preference[？?]?)([^\\\n.]+)/i)&.[](1)&.strip
  end
end
