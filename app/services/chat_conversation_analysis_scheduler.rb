class ChatConversationAnalysisScheduler
  class NoMessages < StandardError; end

  def initialize(binding)
    @binding = binding
  end

  def call
    cursor = @binding.chat_captured_messages.maximum(:id)
    raise NoMessages unless cursor

    current = @binding.analysis_result.to_h
    return current if current["status"] == "queued" && current["messageCursor"] == cursor

    result = {
      "status" => "queued",
      "requestedAt" => Time.current.iso8601,
      "messageCursor" => cursor
    }
    @binding.update!(analysis_result: result)
    ChatConversationAnalysisJob.perform_later(@binding.id)
    result
  end
end
