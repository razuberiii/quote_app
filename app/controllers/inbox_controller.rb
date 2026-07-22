class InboxController < ApplicationController
  def index
    redirect_to quotes_path, status: :moved_permanently
  end
end
