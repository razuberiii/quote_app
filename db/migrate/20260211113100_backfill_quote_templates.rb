class BackfillQuoteTemplates < ActiveRecord::Migration[8.1]
  def up
    Company.find_each do |company|
      company.create_quote_template! unless company.quote_template
    end
  end

  def down
    QuoteTemplate.delete_all
  end
end
