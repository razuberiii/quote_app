class ProductSpecPreset < ApplicationRecord
  belongs_to :product
  belongs_to :spec_preset
end
