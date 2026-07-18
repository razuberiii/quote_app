class AddPaymentToFinalDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :final_documents, :payment_received_at, :datetime
    add_column :final_documents, :payment_note, :text
  end
end
