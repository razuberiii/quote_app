class OnboardingController < ApplicationController
  def dismiss
    current_user.update!(dismissed_onboarding: true)
    redirect_to inbox_index_path, notice: "Setup prompt dismissed."
  end
end
