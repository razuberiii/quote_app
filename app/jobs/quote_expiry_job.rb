class QuoteExpiryJob < ApplicationJob
  queue_as :default

  def perform
    Company.find_each do |company|
      Quote.expire_overdue_for_company!(company.id)
    end
  end
end
