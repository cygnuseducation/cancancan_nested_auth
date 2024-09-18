module CanCanCan
  module NestedAssignmentAndAuthorization
    class Configuration
      attr_accessor :silence_raised_errors, :use_resource_key_in_params, :implicitly_allow_nested_attributes

      def initialize
        # Allows for stopping unauthorized actions without raising errors
        @silence_raised_errors = false

        # Set to `true` if you're nesting parameter data under the resource_key
        # - i.e. params => {user: {email: 'test', name: 'fun'}}
        # Set to `false` if resource parameter data is direct in in params.
        # - i.e. params => {email: 'test', name: 'fun'}
        @use_resource_key_in_params = true

        # Set to `true` to implicitly allow access to the {child_class}_attributes parameter.
        # Set to `false` to require explicit permissions in Ability, i.e.:
        #     can :update, [:post_attributes], User
        # Note that either way, the Ability needs permissions for operations on
        # the nested model.
        @implicitly_allow_nested_attributes = true
      end
    end
  end
end
