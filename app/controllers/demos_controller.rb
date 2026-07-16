class DemosController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_marketing"
  def seller; end

  def buyer
    @revision = QuoteRevision.includes(:company, quote: :customer).joins(:company).find_by(companies: { name: "Atlas Industrial Supply Co." })
    return unless @revision

    @snapshot = @revision.snapshot
    @state = "normal"
    render "buyer_rooms/show", layout: "buyer_room"
  end
end
