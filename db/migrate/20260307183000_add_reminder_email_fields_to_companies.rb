class AddReminderEmailFieldsToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :reminder_email_subject, :string
    add_column :companies, :reminder_email_body, :text
    add_column :companies, :reminder_email_cta_label, :string
  end
end
