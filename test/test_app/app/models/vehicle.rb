class Vehicle < ApplicationRecord
  has_many :parts, as: :partable
  belongs_to :user

  accepts_nested_attributes_for :parts, allow_destroy: true

  def make_and_model
    "#{make} #{model}"
  end
end
