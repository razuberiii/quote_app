class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def require_admin!
    redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
  end
end
