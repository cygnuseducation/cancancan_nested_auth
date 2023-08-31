
# cancancan_nested_auth
Apply CanCanCan authorization checks on individual nested objects

# Install (add to Gemfile)
```
gem 'cancancan_nested_auth', '~> 1'
```

# Init:
Create init file: config/initializers/cancancan_nested_auth.rb and populate it with the following:

```
require "cancancan_nested_auth"
# default values shown
CanCanCan::NestedAssignmentAndAuthorization.configure do |config|
  # Allows for stopping unauthorized actions without raising errors
  # - Will let root object (and valid, other nested objects) save, even if an invalid nested object exists, if true
  config.silence_raised_errors = false
  # Auto-determine what action to auth on nested associations (:create, :update, :destroy)
  # - :create if is a new record
  # - :update if pre-existing record
  # - :destroy if :_destroy parameter is present
  # - will use the action of the root object if set to false
  config.use_smart_nested_authorizations = true
end
```

## Example usage
```
require 'cancancan_nested_assignment_and_authorization'
class VehiclesController < ActionController::Base
  def update
    authorize! :update, Vehicle
    @vehicle ||= Vehicle.find(params[:id])
    service = CanCan::AssignmentAndAuthorization.new(
      current_ability,
      action_name,
      @vehicle,
      # unsanitized params, they will be checked against CanCan's permitted attributes.
      params #params must point to the root object data, so also possibly `params[:vehicle]`
    )

    if service.call
      redirect_to @vehicle, notice: 'Vehicle was successfully updated.'
    else
      render :edit
    end
  end
end
```
