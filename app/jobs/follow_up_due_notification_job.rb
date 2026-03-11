class FollowUpDueNotificationJob < ApplicationJob
  queue_as :default

  def perform
    Customer
      .where(next_follow_up_date: Date.current)
      .includes(:company)
      .find_each do |customer|
        reference_quote = latest_actionable_quote(customer)
        next if reference_quote.blank?

        owner = customer.internal_owner if customer.respond_to?(:internal_owner)
        owner ||= customer.company.users.company_owner.order(:created_at).first
        owner ||= customer.company.users.company_admin.order(:created_at).first
        next if owner.blank?

        ActionItem.find_or_create_by!(
          user: owner,
          action_type: "follow_up_due",
          reference: reference_quote
        )
      rescue StandardError => e
        Rails.logger.warn("FollowUpDueNotificationJob skipped customer=#{customer.id}: #{e.class} #{e.message}")
      end
  end

  private

  def latest_actionable_quote(customer)
    customer.quotes.not_archived.latest_versions.order(updated_at: :desc).first || customer.quotes.order(updated_at: :desc).first
  end
end
