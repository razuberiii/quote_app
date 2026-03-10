class ActionItemsController < ApplicationController
  def resolve
    action_item = current_user.action_items.find(params[:id])
    action_item.update!(resolved_at: Time.current)

    redirect_back fallback_location: dashboard_path, notice: t("flash.action_item_resolved")
  end
end
