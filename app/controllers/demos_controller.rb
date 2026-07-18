class DemosController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_marketing"
  def seller
    @company = demo_company
    @quote = @company&.quotes&.includes(:customer, :quote_items, :quote_revisions, :buyer_activities)&.order(updated_at: :desc)&.first
    @revision = @quote&.quote_revisions&.ordered&.first
    @snapshot = @revision&.snapshot || {}
  end

  def buyer
    @revision = QuoteRevision.includes(:company, quote: :customer)
      .where(company: demo_company).ordered.first
    return unless @revision

    @snapshot = @revision.snapshot
    @state = "normal"
    render "buyer_rooms/show", layout: "buyer_room"
  end

  private

  def demo_company
    return Company.find_by(slug: "visual-review-machinery") if Rails.env.test?

    Company.find_by(name: "Atlas Industrial Supply Co.")
  end
end
