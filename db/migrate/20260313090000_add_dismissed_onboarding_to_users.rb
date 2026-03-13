class AddDismissedOnboardingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dismissed_onboarding, :boolean, default: false, null: false
  end
end
