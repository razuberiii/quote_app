class DemosController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_marketing"
  def seller; end
  def buyer; end
end
