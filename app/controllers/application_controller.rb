class ApplicationController < ActionController::Base
  include TurnstileVerifiable

  before_action :authenticate_user!
  before_action :set_locale
  before_action :ensure_email_verified!
  before_action :configure_permitted_parameters, if: :devise_controller?
  helper_method :pending_team_invitations_count, :ui_brand_color, :ui_brand_text_color,
                :locale_nav_items, :current_locale_nav_item, :locale_switch_url

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def set_locale
    locale = params[:locale].presence || current_user&.language.presence
    normalized_locale = locale.to_s.tr("_", "-")

    I18n.locale = if I18n.available_locales.map(&:to_s).include?(normalized_locale)
      normalized_locale
    else
      I18n.default_locale
    end
  end

  def default_url_options
    return {} if I18n.locale.to_s == I18n.default_locale.to_s

    { locale: I18n.locale }
  end

  def locale_nav_items
    [
      { locale: :en, label: "English", short_label: "EN" },
      { locale: :"zh-CN", label: "简体中文", short_label: "中文" },
      { locale: :"es-419", label: "Espanol (LatAm)", short_label: "ES" }
    ]
  end

  def current_locale_nav_item
    locale_nav_items.find { |item| item[:locale].to_s == I18n.locale.to_s } || locale_nav_items.first
  end

  def locale_switch_url(target_locale)
    locale = target_locale.to_s

    if request.get?
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

    # Allow existing users (created before email verification feature) to use the system
    # These are users who have no verification token/timestamp, meaning they signed up before this feature
    return if current_user.email_verification_token.blank? && current_user.email_verification_token_sent_at.blank?

    redirect_to pending_email_verification_path(email: current_user.email), alert: t("flash.verify_email")
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

  def require_company_team_manager!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.can_manage_team?
  end

  def require_company_template_manager!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.can_manage_templates?
  end

  def require_company_settings_manager!
    redirect_to root_path, alert: t("flash.not_authorized") unless current_user&.can_manage_templates?
  end

  def pending_team_invitations_count
    return 0 unless current_user.present?

    TeamInvitation.active.where("LOWER(email) = ?", current_user.email.to_s.downcase).count
  end

  def ui_brand_color
    current_user&.company&.brand_color.presence || "#1F4E79"
  end

  def ui_brand_text_color
    contrast_color_for(ui_brand_color)
  end

  def configure_permitted_parameters
    profile_keys = [ :avatar, :remove_avatar, :full_name, :contact_phone, :job_title, :time_zone, :language ]
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :avatar, :full_name, :time_zone, :language ])
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
end
