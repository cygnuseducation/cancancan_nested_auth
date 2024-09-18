
# cancancan_nested_auth
Apply CanCanCan authorization checks on individual nested objects

# Install (add to Gemfile)
```
gem 'cancancan_nested_auth', '~> 0'
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
  # Set to `true` if you're nesting parameter data under the resource_key
  # - i.e. params => {user: {email: 'test', name: 'fun'}}
  # Set to `false` if resource parameter data is direct in in params.
  # - i.e. params => {email: 'test', name: 'fun'}
  config.use_resource_key_in_params = false
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
