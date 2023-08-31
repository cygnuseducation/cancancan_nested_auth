class Brand < ApplicationRecord
  # can belong to car, or as a sub-part of a part.
  has_many :brands_parts
  has_many :parts, through: :brands_parts
end