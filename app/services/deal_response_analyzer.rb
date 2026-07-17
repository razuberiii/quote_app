class DealResponseAnalyzer
  def initialize(response)
    @response = response
  end

  def call
    result = { "review_required" => true, "source" => @response.source }
    result.merge!(ReturnedVersionComparator.new(@response).call) if @response.kind == "returned_excel" && @response.attachment.attached?
    if @response.kind == "purchase_order"
      result.merge!(PurchaseOrderComparator.new(@response).call)
    end
    result
  end
end
