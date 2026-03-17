class NormalizeCustomerLevelsAndDistributorTag < ActiveRecord::Migration[8.0]
  class MigrationCustomer < ApplicationRecord
    self.table_name = "customers"
  end

  class MigrationCustomerTag < ApplicationRecord
    self.table_name = "customer_tags"
  end

  class MigrationCustomerTagging < ApplicationRecord
    self.table_name = "customer_taggings"
  end

  def up
    now = Time.current

    MigrationCustomer.where(customer_level: "vip").update_all(customer_level: "key_account", updated_at: now)

    distributor_customers = MigrationCustomer.where(customer_level: "distributor")
    company_ids = distributor_customers.distinct.pluck(:company_id)
    distributor_tags = company_ids.index_with do |company_id|
      existing = MigrationCustomerTag.where(company_id:).where("LOWER(name) = ?", "distributor").first
      existing || MigrationCustomerTag.create!(company_id:, name: "Distributor")
    end

    distributor_customers.find_each do |customer|
      tag = distributor_tags[customer.company_id]
      next unless tag

      MigrationCustomerTagging.find_or_create_by!(customer_id: customer.id, customer_tag_id: tag.id) do |tagging|
        tagging.position = MigrationCustomerTagging.where(customer_id: customer.id).maximum(:position).to_i + 1
      end
    end

    distributor_customers.update_all(customer_level: "normal", updated_at: now)

    MigrationCustomerTag.where("LOWER(name) = ?", "vip").find_each do |vip_tag|
      customer_ids = MigrationCustomerTagging.where(customer_tag_id: vip_tag.id).pluck(:customer_id).uniq
      MigrationCustomer.where(id: customer_ids).where.not(customer_level: "key_account").update_all(customer_level: "key_account", updated_at: now)
      MigrationCustomerTagging.where(customer_tag_id: vip_tag.id).delete_all
      vip_tag.delete
    end
  end

  def down
    # irreversible data normalization
  end
end
