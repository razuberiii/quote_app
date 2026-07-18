class DefaultUsersToChinese < ActiveRecord::Migration[8.0]
  def change
    change_column_default :users, :language, from: nil, to: "zh-CN"
    change_column_default :quotes, :language, from: "en", to: "zh-CN"
    change_column_default :companies, :quote_language, from: "en", to: "zh-CN"
  end
end
