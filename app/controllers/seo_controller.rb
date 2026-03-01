class SeoController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  def foreign_trade_quotation_software; end

  def quotation_crm_for_export_teams; end
end
