module CanCanCan
  module NestedAssignmentAndAuthorization
    class Configuration
      attr_accessor :silence_raised_errors, :use_smart_nested_authorizations, :use_resource_key_in_params

      def initialize
        # Allows for stopping unauthorized actions without raising errors
        @silence_raised_errors = false
        # Auto-determine what action to auth on nested associations (:create, :update, :destroy)
        # - will use the action of the root object otherwise.
        @use_smart_nested_authorizations = true
        # Set to `true` if you're nesting parameter data under the resource_key
        # - i.e. params => {user: {email: 'test', name: 'fun'}}
        # Set to `false` if resource parameter data is direct in in params.
        # - i.e. params => {email: 'test', name: 'fun'}
        @use_resource_key_in_params = true
      end
    end
  end
end