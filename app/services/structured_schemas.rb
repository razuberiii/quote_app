module StructuredSchemas
  def self.nullable_string = { "type" => [ "string", "null" ] }
  def self.nullable_number = { "type" => [ "number", "null" ] }
  def self.array(items) = { "type" => "array", "items" => items }
  def self.object(properties, required) = { "type" => "object", "additionalProperties" => false, "required" => required, "properties" => properties }

  VERSION = "2026-07-18".freeze

  INQUIRY = {
    "type" => "object", "additionalProperties" => false,
    "required" => %w[customer contact country currency products commercial_terms missing_fields ambiguities warnings evidence],
    "properties" => {
      "customer" => nullable_string,
      "contact" => object({ "name" => nullable_string, "email" => nullable_string }, %w[name email]),
      "country" => nullable_string, "currency" => nullable_string,
      "products" => array(object({
        "name" => { "type" => "string" }, "model" => nullable_string,
        "quantity" => nullable_number, "unit" => nullable_string,
        "specifications" => { "type" => "object", "additionalProperties" => { "type" => [ "string", "null" ] } },
        "packing" => nullable_string, "lead_time" => nullable_string,
        "image_candidates" => array({ "type" => "string" }), "catalog_candidates" => array({ "type" => "string" }),
        "confidence" => { "type" => "number", "minimum" => 0, "maximum" => 1 },
        "evidence_ids" => array({ "type" => "string" })
      }, %w[name model quantity unit specifications packing lead_time image_candidates catalog_candidates confidence evidence_ids])),
      "commercial_terms" => object({
        "incoterm" => nullable_string, "destination" => nullable_string,
        "payment" => nullable_string, "delivery" => nullable_string, "packing" => nullable_string
      }, %w[incoterm destination payment delivery packing]),
      "missing_fields" => array({ "type" => "string" }), "ambiguities" => array({ "type" => "string" }),
      "warnings" => array({ "type" => "string" }),
      "evidence" => array(object({
        "id" => { "type" => "string" }, "field_path" => { "type" => "string" },
        "excerpt" => { "type" => "string" }, "source" => { "type" => "string" },
        "location" => { "type" => [ "string", "null" ] }
      }, %w[id field_path excerpt source location]))
    }
  }.freeze

  CATALOG = {
    "type" => "object", "additionalProperties" => false, "required" => %w[products warnings evidence],
    "properties" => {
      "products" => array(object({
        "name" => { "type" => "string" }, "sku" => nullable_string, "model" => nullable_string,
        "category" => nullable_string, "description" => nullable_string, "unit" => nullable_string,
        "specifications" => { "type" => "object", "additionalProperties" => { "type" => [ "string", "null" ] } },
        "variants" => array(object({ "name" => { "type" => "string" }, "sku" => nullable_string,
          "specifications" => { "type" => "object", "additionalProperties" => { "type" => [ "string", "null" ] } },
          "explicit_price" => nullable_number, "currency" => nullable_string },
          %w[name sku specifications explicit_price currency])), "moq" => nullable_number, "lead_time" => nullable_string,
        "packing" => nullable_string, "weight" => nullable_string, "dimensions" => nullable_string,
        "country_of_origin" => nullable_string, "hs_code" => nullable_string,
        "certifications" => array({ "type" => "string" }), "explicit_price" => nullable_number,
        "currency" => nullable_string, "price_valid_until" => nullable_string,
        "image_candidates" => array({ "type" => "string" }), "confidence" => { "type" => "number", "minimum" => 0, "maximum" => 1 },
        "evidence_ids" => array({ "type" => "string" })
      }, %w[name sku model category description unit specifications variants moq lead_time packing weight dimensions country_of_origin hs_code certifications explicit_price currency price_valid_until image_candidates confidence evidence_ids])),
      "warnings" => array({ "type" => "string" }),
      "evidence" => INQUIRY.dig("properties", "evidence")
    }
  }.freeze

  def self.validate!(value, schema, path = "$")
    types = Array(schema["type"])
    valid_type = types.any? { |type| type_match?(value, type) }
    raise ArgumentError, "#{path} must be #{types.join(' or ')}" unless valid_type
    return true if value.nil?

    if types.include?("object")
      missing = Array(schema["required"]) - value.keys
      raise ArgumentError, "#{path} missing #{missing.join(', ')}" if missing.any?
      if schema["additionalProperties"] == false
        unknown = value.keys - schema.fetch("properties", {}).keys
        raise ArgumentError, "#{path} contains unknown fields: #{unknown.join(', ')}" if unknown.any?
      end
      value.each do |key, child|
        child_schema = schema.fetch("properties", {})[key]
        child_schema ||= schema["additionalProperties"] if schema["additionalProperties"].is_a?(Hash)
        validate!(child, child_schema, "#{path}.#{key}") if child_schema
      end
    elsif types.include?("array")
      value.each_with_index { |child, index| validate!(child, schema["items"], "#{path}[#{index}]") }
    elsif types.include?("number")
      raise ArgumentError, "#{path} is below minimum" if schema["minimum"] && value < schema["minimum"]
      raise ArgumentError, "#{path} is above maximum" if schema["maximum"] && value > schema["maximum"]
    end
    true
  end

  def self.type_match?(value, type)
    { "null" => value.nil?, "string" => value.is_a?(String), "number" => value.is_a?(Numeric),
      "object" => value.is_a?(Hash), "array" => value.is_a?(Array) }.fetch(type, false)
  end
  private_class_method :type_match?
end
