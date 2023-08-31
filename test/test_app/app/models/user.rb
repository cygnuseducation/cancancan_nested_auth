class User < ApplicationRecord
  has_many :vehicles, inverse_of: :user
  has_many :parts, through: :vehicles
  has_many :groups_users
  has_many :groups, through: :groups_users
  accepts_nested_attributes_for :vehicles, allow_destroy: true

  def current_ability
    @current_ability ||= Ability.new(self)
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
