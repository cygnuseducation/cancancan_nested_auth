class BrandsPart < ApplicationRecord
  belongs_to :part
  belongs_to :brand
end
