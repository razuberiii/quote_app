module Admin
  class UsersController < BaseController
    PER_PAGE = 25

    before_action :set_user, only: [ :show, :update_role, :update_status, :impersonate ]

    def index
      @query = params[:q].to_s.strip
      @page = [ params[:page].to_i, 1 ].max
      scope = User.includes(:company).order(id: :desc)
      scope = apply_search(scope, @query) if @query.present?

      @total_count = scope.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @users = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end

    def show
      company = @user.company
      quotes_scope = company.quotes.not_archived
      quote_count = quotes_scope.count
      quote_families = quotes_scope.where.not(quote_no: nil).distinct.count(:quote_no)

      @summary = {
        customers_count: company.customers.count,
        quotes_count: quote_count,
        revisions_count: [ quote_count - quote_families, 0 ].max,
        public_shares_count: company.quote_shares.count
      }
    end

    def update_role
      if @user == acting_user_for_audit
        redirect_back fallback_location: admin_user_path(@user), alert: t("admin.users.flash.cannot_change_own_role") and return
      end

      target_role = role_param
      if @user.admin? && target_role != "admin" && User.where(role: :admin).count <= 1
        redirect_back fallback_location: admin_user_path(@user), alert: t("admin.users.flash.cannot_demote_last_admin") and return
      end

      before_role = @user.role
      @user.role = target_role

      if @user.save
        Admin::AuditLogger.log!(
          actor: acting_user_for_audit,
          target: @user,
          action: :role_changed,
          metadata: { before_role: before_role, after_role: @user.role }
        )
        redirect_back fallback_location: admin_user_path(@user), notice: t("admin.users.flash.role_updated")
      else
        redirect_back fallback_location: admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
      end
    end

    def update_status
      before_status = @user.status
      @user.status = status_param

      if @user.save
        Admin::AuditLogger.log!(
          actor: acting_user_for_audit,
          target: @user,
          action: :status_changed,
          metadata: { before_status: before_status, after_status: @user.status }
        )
        redirect_back fallback_location: admin_user_path(@user), notice: t("admin.users.flash.status_updated")
      else
        redirect_back fallback_location: admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
      end
    end

    def impersonate
      if @user.admin?
        redirect_back fallback_location: admin_user_path(@user), alert: t("admin.users.flash.cannot_impersonate_admin") and return
      end

      admin_actor = current_user
      session[:admin_impersonator_id] = admin_actor.id
      session[:impersonated_user_id] = @user.id
      sign_in(:user, @user)

      Admin::AuditLogger.log!(
        actor: admin_actor,
        target: @user,
        action: :impersonation_started,
        metadata: {
          impersonated_user_id: @user.id,
          impersonated_user_email: @user.email
        }
      )

      redirect_to dashboard_path, notice: t("admin.users.flash.impersonation_started", email: @user.email)
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def role_param
      role = params.require(:user).fetch(:role).to_s
      return role if User.roles.key?(role)

      raise ActionController::BadRequest, "Invalid role"
    end

    def status_param
      status = params.require(:user).fetch(:status).to_s
      return status if User.statuses.key?(status)

      raise ActionController::BadRequest, "Invalid status"
    end

    def apply_search(scope, query)
      q = "%#{query.downcase}%"
      scope.left_joins(:company).where(
        "LOWER(users.email) LIKE :q OR LOWER(COALESCE(users.full_name, '')) LIKE :q OR LOWER(COALESCE(companies.name, '')) LIKE :q",
        q: q
      )
    end
  end
end
