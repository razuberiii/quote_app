class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  helper_method :pending_team_invitations_count, :ui_brand_color, :ui_brand_text_color

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def require_admin!
    redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
  end

  def require_company_team_manager!
    redirect_to root_path, alert: "Not authorized." unless current_user&.can_manage_team?
  end

  def require_company_template_manager!
    redirect_to root_path, alert: "Not authorized." unless current_user&.can_manage_templates?
  end

  def require_company_settings_manager!
    redirect_to root_path, alert: "Not authorized." unless current_user&.can_manage_templates?
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
