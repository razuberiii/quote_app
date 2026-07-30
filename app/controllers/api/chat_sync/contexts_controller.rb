module Api
  module ChatSync
    class ContextsController < BaseController
      def show
        key = context_params
        binding = current_company.chat_conversation_bindings.find_by(
          platform: key[:platform], platform_account_id: key[:platformAccountId],
          platform_conversation_id: key[:platformConversationId]
        )
        render json: {
          binding: binding && binding_payload(binding),
          customers: current_company.customers.order(updated_at: :desc).limit(100).map { |customer|
            { id: customer.id, name: customer.name, contactName: customer.contact_name }
          },
          inquiries: current_company.inquiries.order(updated_at: :desc).limit(100).map { |inquiry|
            { id: inquiry.id, customerId: inquiry.customer_id, label: inquiry_label(inquiry) }
          }
        }
      end

      private

      def context_params
        params.permit(:platform, :platformAccountId, :platformConversationId)
      end

      def inquiry_label(inquiry)
        inquiry.customer&.name.presence || inquiry.extracted_data["customer"].presence || "Inquiry ##{inquiry.id}"
      end

      def binding_payload(binding)
        {
          id: binding.id, platform: binding.platform, displayName: binding.display_name,
          customerId: binding.customer_id, inquiryId: binding.inquiry_id,
          paused: binding.paused, autoAnalysis: binding.auto_analysis,
          messageCount: binding.chat_captured_messages.count,
          lastSyncedAt: binding.last_synced_at&.iso8601,
          lastAnalyzedAt: binding.last_analyzed_at&.iso8601,
          analysisResult: binding.analysis_result
        }
      end
    end
  end
end
