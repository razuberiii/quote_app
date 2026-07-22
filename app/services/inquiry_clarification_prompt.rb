class InquiryClarificationPrompt
  def initialize(inquiry)
    @data = inquiry.extracted_data.deep_stringify_keys
  end

  def questions
    questions = []
    questions << I18n.t("self_service.conversation.prompts.customer") if @data["customer"].blank?
    questions << I18n.t("self_service.conversation.prompts.currency") if @data["currency"].blank?
    questions << I18n.t("self_service.conversation.prompts.destination") if terms["destination"].blank?
    questions << I18n.t("self_service.conversation.prompts.incoterm") if terms["incoterm"].blank?
    questions << I18n.t("self_service.conversation.prompts.delivery") if terms["delivery"].blank?
    questions << I18n.t("self_service.conversation.prompts.product") if Array(@data["products"]).empty?
    questions.concat(Array(@data["missing_information"]).first(3))
    questions.uniq.first(5)
  end

  private

  def terms
    @data.fetch("commercial_terms", {})
  end
end
