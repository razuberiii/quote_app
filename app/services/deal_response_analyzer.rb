class DealResponseAnalyzer
  def initialize(response)
    @response = response
  end

  def call
    result = { "review_required" => true, "source" => @response.source }
    if @response.kind == "returned_excel" && @response.attachment.attached?
      inspection = ReturnedFileInspector.new(@response.attachment).call
      result.merge!("unsafe_formula_count" => inspection.unsafe_cells.size,
        "unsafe_cells" => inspection.unsafe_cells, "formula_count" => inspection.formulas.size,
        "formula_policy" => "untrusted_never_executed")
    end
    if @response.kind == "purchase_order"
      quoted_total = @response.quote_revision.total.to_d
      stated_total = @response.body.to_s[/\b(?:total|amount)\s*[:=]?\s*[A-Z]{0,3}\s*([\d,.]+)/i, 1].to_s.delete(",").to_d
      severity = if stated_total.zero?
        "review_required"
      elsif stated_total == quoted_total
        "exact_match"
      elsif (stated_total - quoted_total).abs <= quoted_total * BigDecimal("0.01")
        "minor_difference"
      else
        "material_difference"
      end
      result.merge!("quoted_total" => quoted_total.to_s("F"), "stated_total" => stated_total.to_s("F"), "severity" => severity)
    end
    result
  end
end
