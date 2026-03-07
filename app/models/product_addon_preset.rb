class ProductAddonPreset < ApplicationRecord
  belongs_to :product
  belongs_to :addon_preset
end
