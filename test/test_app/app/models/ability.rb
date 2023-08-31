class Ability
  include CanCan::Ability

  def initialize(user = nil)
    roles = user&.role&.split(';') || []
    if user&.email.present?
      can :update, User, [:first_name, :last_name], { email: user.email }
    end

    if roles.include?('staff')
      can :update, User, [:first_name, :last_name, :vehicles_attributes, :group_ids]
      can :update, Vehicle, [:make, :model, :parts_attributes, :id]
      can :update, Part, [:id, :name, :brand_ids]
    end

    # test case where we only allow creates
    if roles.include?('creative')
      can :create, User, [:first_name, :last_name, :vehicles_attributes, :group_ids, :email]
      can :create, Vehicle, [:make, :model, :parts_attributes, :id]
      can :create, Part, [:id, :name, :brand_ids]
    end

    # test case where we only allow creates
    if roles.include?('vehicle-creator')
      can :create, Vehicle
    end

    if (roles & ['vehicle-creator', 'user-creator']).count == 2
      can :create, User, [:first_name, :last_name, :email, :vehicles_attributes, :group_ids]
    end
  end
end
