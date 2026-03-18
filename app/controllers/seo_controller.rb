class SeoController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!
  layout "public_marketing"
  before_action :set_seo_page

  def foreign_trade_quotation_software; end

  def quote_revision_control; end

  def buyer_facing_quotation_link; end

  def quotation_software_vs_excel; end

  def quotation_software_vs_erp; end

  def quick_export_quotation; end

  def resources; end

  private

  def set_seo_page
    @seo_page = SeoPageRegistry.fetch(action_name)
  end
end
