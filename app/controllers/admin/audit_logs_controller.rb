module Admin
  class AuditLogsController < BaseController
    PER_PAGE = 50

    def index
      @page = [ params[:page].to_i, 1 ].max
      scope = AuditLog.includes(:actor).order(created_at: :desc)
      @total_count = scope.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @audit_logs = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end
  end
end
