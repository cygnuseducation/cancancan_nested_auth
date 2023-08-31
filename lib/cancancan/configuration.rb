module CanCanCan
  module NestedAuth
    class Configuration
      attr_accessor :silence_raised_errors, :use_smart_nested_authorizations

      def initialize
        # Allows for stopping unauthorized actions without raising errors
        @silence_raised_errors = false
        # Auto-determine what action to auth on nested associations (:create, :update, :destroy)
        # - will use the action of the root object otherwise.
        @use_smart_nested_authorizations = true
      end
    end
  end
end