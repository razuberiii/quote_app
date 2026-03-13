class CustomerEngagementStateRefreshJob < ApplicationJob
  queue_as :default

  def perform
    Customer.find_each do |customer|
      customer.refresh_engagement_state!
    end
  end
end
