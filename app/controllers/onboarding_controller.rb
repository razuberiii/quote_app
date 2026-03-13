class OnboardingController < ApplicationController
  def dismiss
    current_user.update!(dismissed_onboarding: true)
    redirect_to dashboard_path, notice: "Onboarding dismissed."
  end
end
