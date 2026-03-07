class AddReasonDetailFieldsToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :win_reason_detail, :string
    add_column :quotes, :loss_reason_detail, :string
    add_column :quotes, :stalled_reason_detail, :string
  end
end
