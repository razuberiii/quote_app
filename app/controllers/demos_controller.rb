class DemosController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_marketing"
  def seller
    @company = Company.find_by(name: "Atlas Industrial Supply Co.")
    @quote = @company&.quotes&.includes(:customer, :quote_items, :quote_revisions, :buyer_activities)&.order(updated_at: :desc)&.first
    @revision = @quote&.quote_revisions&.ordered&.first
    @snapshot = @revision&.snapshot || {}
  end

  def buyer
    @revision = QuoteRevision.includes(:company, quote: :customer).joins(:company).find_by(companies: { name: "Atlas Industrial Supply Co." })
    return unless @revision

    @snapshot = @revision.snapshot
    @state = "normal"
    render "buyer_rooms/show", layout: "buyer_room"
  end
end
