class ApplicationController < ActionController::Base
  include TurnstileVerifiable

  before_action :authenticate_user!
  before_action :enforce_canonical_host!
  before_action :set_locale
  before_action :normalize_impersonation_session!
  before_action :enforce_active_user_status!
  before_action :touch_last_active_at!
  before_action :ensure_email_verified!
  before_action :configure_permitted_parameters, if: :devise_controller?
  helper_method :ui_brand_color, :ui_brand_text_color,
                :locale_nav_items, :current_locale_nav_item, :locale_switch_url,
                :impersonating?, :real_admin_user, :acting_user_for_audit

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  protected

  def after_sign_in_path_for(resource)
    return admin_root_path if resource.respond_to?(:admin?) && resource.admin?

    authenticated_root_path
  end

  private

  def enforce_canonical_host!
    return unless Rails.env.production?
    return unless request.host.to_s.casecmp("rubusoo.com").zero?

    redirect_to "#{request.protocol}www.rubusoo.com#{request.fullpath}", status: :moved_permanently, allow_other_host: true
  end

  def set_locale
    available_locales = I18n.available_locales.map(&:to_s)
    requested_locale = params[:locale].presence.to_s.tr("_", "-")
    user_locale = current_user&.language.to_s.tr("_", "-")
    candidate = requested_locale.presence || user_locale.presence

    resolved_locale =
      if available_locales.include?(candidate)
        candidate
      else
        I18n.default_locale.to_s
      end

    I18n.locale = resolved_locale
    persist_user_locale_preference!(requested_locale, available_locales)
  end

  def persist_user_locale_preference!(requested_locale, available_locales)
    return if current_user.blank?
    return if requested_locale.blank?
    return unless available_locales.include?(requested_locale)
    return if current_user.language.to_s == requested_locale

    current_user.update_column(:language, requested_locale)
  end

  def default_url_options
    locale = I18n.locale.to_s
    return { locale: locale } if locale_path_enabled_controller?
    {}
  end

  def locale_path_enabled_controller?
    controller_path.in?([ "landing", "seo", "contact_requests", "sitemaps" ])
  end

  def trusted_public_url_options
    configured = Rails.application.config.action_mailer.default_url_options || {}
    host = ENV["APP_HOST"].presence || configured[:host].presence
    protocol = ENV["RAILS_PROTOCOL"].presence || configured[:protocol].presence
    protocol = protocol.to_s.delete_suffix("://").presence || (Rails.env.production? ? "https" : request.protocol.delete_suffix("://"))

    if host.present?
      options = { host: host, protocol: protocol }
      configured_port = configured[:port].presence
      if configured_port.present? && !default_port_for_protocol?(configured_port, protocol)
        options[:port] = configured_port
      end
      return options
    end

    { host: request.host, protocol: request.protocol.delete_suffix("://"), port: request.optional_port }
  end

  def locale_nav_items
    [
      { locale: :"zh-CN", label: "简体中文", short_label: "中文" }
    ]
  end

  def current_locale_nav_item
    locale_nav_items.find { |item| item[:locale].to_s == I18n.locale.to_s } || locale_nav_items.first
  end

  def locale_switch_url(target_locale)
    locale = target_locale.to_s

    if request.get? || request.head?
      return url_for(locale: locale)
    end

    referer = request.referer.to_s
    if referer.present?
      begin
        uri = URI.parse(referer)
        path = uri.path.presence || authenticated_root_path
        referer_query = Rack::Utils.parse_nested_query(uri.query.to_s)
        merged_query = referer_query.merge("locale" => locale)
        query_string = merged_query.to_query
        return query_string.present? ? "#{path}?#{query_string}" : path
      rescue URI::InvalidURIError
        # Fallback below.
      end
    end

    authenticated_root_path(locale: locale)
  rescue ActionController::UrlGenerationError
    authenticated_root_path(locale: locale)
  end

  def ensure_email_verified!
    # Skip in development environment
    return if Rails.env.development?

    # Skip this check for certain controllers/actions
    return if should_skip_email_verification_check?
    return if current_user.blank?
    return if current_user.email_verified?

    redirect_to pending_email_verification_path(email: current_user.email), alert: t("flash.verify_email")
  end

  def normalize_impersonation_session!
    return unless impersonating?
    return if real_admin_user&.admin?

    clear_impersonation_session!
  end

  def enforce_active_user_status!
    return if current_user.blank?
    return if should_skip_status_enforcement_check?
    return if current_user.active_for_app?

    if impersonating? && real_admin_user&.admin?
      admin_actor = real_admin_user
      impersonated_user = current_user

      Admin::AuditLogger.log!(
        actor: admin_actor,
        target: impersonated_user,
        action: :impersonation_stopped,
        metadata: {
          impersonated_user_id: impersonated_user.id,
          impersonated_user_email: impersonated_user.email,
          stop_reason: "target_no_longer_active"
        }
      )

      clear_impersonation_session!
      sign_in(:user, admin_actor)
      redirect_to admin_root_path, alert: t("admin.impersonation.flash.target_no_longer_active") and return
    end

    clear_impersonation_session!
    sign_out(current_user)
    redirect_to suspended_path, alert: t("users.suspended.alert")
  end

  def should_skip_status_enforcement_check?
    return true if controller_name == "devise_sessions" && action_name == "destroy"
    return true if controller_name == "suspended_access"

    false
  end

  def touch_last_active_at!
    return if current_user.blank?
    return unless current_user.active_for_app?

    threshold = 5.minutes.ago
    return if current_user.last_active_at.present? && current_user.last_active_at > threshold

    current_user.update_column(:last_active_at, Time.current)
  end

  def should_skip_email_verification_check?
    # Skip for Devise controllers (login, signup recovery etc)
    return true if devise_controller?
    # Skip for email verifications controller
    return true if controller_name == "email_verifications"
    # Skip for users signout
    return true if controller_name == "devise_sessions" && action_name == "destroy"
    # Skip for email changes
    return true if controller_name == "email_changes"
    false
  end

  def require_admin!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.admin?
  end

  def impersonating?
    session[:admin_impersonator_id].present?
  end

  def real_admin_user
    return nil unless impersonating?
    return @real_admin_user if defined?(@real_admin_user)

    @real_admin_user = User.find_by(id: session[:admin_impersonator_id])
  end

  def acting_user_for_audit
    real_admin_user || current_user
  end

  def clear_impersonation_session!
    session.delete(:admin_impersonator_id)
    session.delete(:impersonated_user_id)
    remove_instance_variable(:@real_admin_user) if defined?(@real_admin_user)
  end

  def require_company_team_manager!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.can_manage_team?
  end

  def require_company_template_manager!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.can_manage_templates?
  end

  def require_company_settings_manager!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.can_manage_templates?
  end

  def ui_brand_color
    current_user&.company&.brand_color.presence || "#1F4E79"
  end

  def ui_brand_text_color
    contrast_color_for(ui_brand_color)
  end

  def configure_permitted_parameters
    profile_keys = [ :avatar, :remove_avatar, :username, :full_name, :contact_phone, :job_title, :time_zone, :language ]
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username, :avatar, :full_name, :time_zone, :language ])
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :login ])
    devise_parameter_sanitizer.permit(:account_update, keys: profile_keys)
  end

  def contrast_color_for(hex_color)
    hex = hex_color.to_s.delete("#")
    return "#ffffff" unless hex.match?(/\A[0-9A-Fa-f]{6}\z/)

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)
    yiq = (r * 299 + g * 587 + b * 114) / 1000
    yiq >= 150 ? "#0f172a" : "#ffffff"
  end

  def default_port_for_protocol?(port, protocol)
    normalized_port = port.to_i
    return true if protocol == "https" && normalized_port == 443
    return true if protocol == "http" && normalized_port == 80

    false
  end
end
