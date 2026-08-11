module Api
  module ChatSync
    class BindingsController < BaseController
      def create
        attributes = binding_params
        binding = current_company.chat_conversation_bindings.find_or_initialize_by(
          platform: attributes[:platform],
          platform_account_id: attributes[:platformAccountId],
          platform_conversation_id: attributes[:platformConversationId]
        )
        customer = resolve_customer(attributes) || binding.customer
        inquiry = if binding.persisted? && attributes[:inquiryId].blank?
          binding.inquiry
        else
          resolve_inquiry(attributes, customer)
        end
        binding.assign_attributes(user: current_user, customer:, inquiry:,
          display_name: attributes[:displayName], paused: false)
        binding.save!
        render json: { binding: binding_payload(binding) }, status: :created
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
        render json: { error: "invalid_binding", details: error.message }, status: :unprocessable_entity
      end

      def update
        binding = current_binding
        binding.paused = ActiveModel::Type::Boolean.new.cast(params[:paused]) unless params[:paused].nil?
        binding.auto_analysis = ActiveModel::Type::Boolean.new.cast(params[:autoAnalysis]) unless params[:autoAnalysis].nil?
        binding.save!
        render json: { binding: binding_payload(binding) }
      end

      def destroy
        binding = current_binding
        binding.destroy!
        head :no_content
      end

      private

      def binding_params
        params.permit(:platform, :platformAccountId, :platformConversationId, :displayName,
          :customerId, :inquiryId, :newCustomerName)
      end

      def resolve_customer(attributes)
        return current_company.customers.find(attributes[:customerId]) if attributes[:customerId].present?
        return if attributes[:newCustomerName].blank?

        current_company.customers.create!(name: attributes[:newCustomerName])
      end

      def resolve_inquiry(attributes, customer)
        return current_company.inquiries.find(attributes[:inquiryId]) if attributes[:inquiryId].present?

        current_company.inquiries.create!(customer:, created_by: current_user,
          source_type: "chat", status: "review", source_text: "")
      end

      def binding_payload(binding)
        {
          id: binding.id, platform: binding.platform, displayName: binding.display_name,
          customerId: binding.customer_id, inquiryId: binding.inquiry_id,
          paused: binding.paused, autoAnalysis: binding.auto_analysis,
          messageCount: binding.chat_captured_messages.count
        }
      end
    end
  end
end
