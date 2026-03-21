module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @new_users_last_7_days = User.where("created_at >= ?", 7.days.ago).count
      @active_users_count = User.active.count
      @suspended_users_count = User.suspended.count
    end
  end
end
