require 'action_controller/railtie'

module CanCanCan
  class AssignmentAndAuthorization
    attr_reader :ability, :action_name, :parent_object, :params

    # to handle adding/removing associations by "_ids" suffix
    # IDS_ATTRIB_PERMISSION_KEY_GEN = Proc.new { |assoc_key| "#{assoc_key.to_s.singularize}_ids".to_sym }
    # IDS_ACTION_PERMISSION_KEY_GEN = Proc.new { |assoc_key| "_can_add_or_remove_association_#{assoc_key.to_s}".to_sym }

    # to handle updating nested attributes
    # NESTED_ATTRIB_PERMISSION_KEY_GEN = Proc.new { |assoc_key| "#{assoc_key}_attributes".to_sym }
    # NESTED_ACTION_PERMISSION_KEY_GEN  = Proc.new { |assoc_key| "_can_update_association_#{assoc_key.to_s}".to_sym }

    def initialize(current_ability, action_name, parent_object, params)
      @ability = current_ability
      @parent_object = parent_object
      @params = params
      if config.use_resource_key_in_params
        @params = @params[parent_object.model_name.singular.to_sym]
      end
      if @params.kind_of?(ActionController::Parameters)
        @params = @params.permit!.to_h
      end
      @action_name = action_name.to_sym
    end

    def call
      # Pre-assignment auth check
      @ability.authorize!(@action_name, @parent_object)

      # sanitized_attribs will only contain attributes, not permitted associations
      sanitized_attribs = sanitize_parameters(@params, @ability.permitted_attributes(@action_name, @parent_object))

      ActiveRecord::Base.transaction do
        # Attributes
        @parent_object.assign_attributes(
          sanitized_attribs.except(
            *@parent_object.class.nested_attributes_options.keys.collect { |v| "#{v}_attributes".to_sym }
          )
        )
        # Associations
        instantiate_and_assign_nested_associations(
          @parent_object,
          sanitize_parameters(
            config.implicitly_allow_nested_attributes ? @params : sanitized_attribs,
            @parent_object.class.nested_attributes_options.keys.collect { |v| "#{v}_attributes".to_sym }
          )
        )
        # Post-assignment auth check
        @ability.authorize!(@action_name, @parent_object)
      end

      @parent_object.save
    rescue CanCan::AccessDenied
      raise unless config.silence_raised_errors

      false
    end

    private

    def config
      CanCanCan::NestedAssignmentAndAuthorization.configuration
    end

    # recursive
    # - param_attribs are not sanitized, as we need to check 2 types of assoc permissions
    #   - action and attrib
    def instantiate_and_assign_nested_associations(parent, param_attribs)
      return if param_attribs.keys.none?

      parent.nested_attributes_options.each_key do |nested_attrib_key|
        param_key = "#{nested_attrib_key}_attributes".to_sym

        next unless param_attribs.key?(param_key)

        reflection = parent.class.reflect_on_association(nested_attrib_key)
        assoc_type = association_type(reflection)

        if assoc_type == :collection
          param_attribs[param_key].each do |attribs|
            save_child_and_child_associations(parent, reflection, nested_attrib_key, attribs)
          end
        elsif assoc_type == :singular
          attribs = param_attribs[param_key]
          child = save_child_and_child_associations(parent, reflection, nested_attrib_key, attribs)
          parent.send("#{nested_attrib_key}=", child) if child
        else
          raise "Unsupported association type: #{reflection.macro}"
        end
      end
    end

    def save_child_and_child_associations parent, reflection, nested_attrib_key, attribs
      assoc_klass = reflection.klass
      child, child_action = save_child(
        parent,
        reflection,
        nested_attrib_key,
        attribs.except(
          *assoc_klass.nested_attributes_options.keys.collect { |v| "#{v}_attributes".to_sym }
        )
      )

      return child if child.nil? || child_action == :destroy

      # recursive call
      instantiate_and_assign_nested_associations(
        child,
        attribs
      )

      child
    end

    # NOT RECURSIVE!
    def save_child parent, reflection, nested_attrib_key, attribs
      # Check permission on parent
      assoc_klass = reflection.klass
      assoc_primary_key = assoc_klass.primary_key.to_sym
      assignment_exceptions = [
        :id,
        :_destroy,
        assoc_primary_key
      ] + assoc_klass.nested_attributes_options.keys.collect{ |v| "#{v}_attributes".to_sym }

      child = if attribs[assoc_primary_key].present?
                parent.send(nested_attrib_key).find_by!(assoc_primary_key => attribs[assoc_primary_key])
              else
                parent.send(nested_attrib_key).build
              end

      child_action = if ActiveRecord::Type::Boolean.new.cast(attribs[:_destroy])
                       :destroy
                     elsif child.new_record?
                       :create
                     else
                       :update
                     end

      return nil if child_action == :destroy && !parent.nested_attributes_options.dig(reflection.name, :allow_destroy)

      # Pre-assignment auth check
      begin
        @ability.authorize!(child_action, child)
      rescue CanCan::AccessDenied
        parent.send(nested_attrib_key).delete(child) if child.new_record?
        raise
      end

      if child_action == :destroy
        parent.send(nested_attrib_key).destroy(child)
        return child
      end

      sanitized_attribs = sanitize_parameters(attribs, @ability.permitted_attributes(child_action, child))

      ActiveRecord::Base.transaction do
        child.assign_attributes(sanitized_attribs.except(*assignment_exceptions))

        # Post-assignment auth check
        begin
          @ability.authorize!(child_action, child)
        rescue CanCan::AccessDenied
          parent.send(nested_attrib_key).delete(child) if child.new_record?
          raise
        end

        parent.association(nested_attrib_key).add_to_target(child, skip_callbacks: true) unless child.new_record?
      end

      [child, child_action]
    rescue CanCan::AccessDenied
      raise unless config.silence_raised_errors
    end

    # Can be overridden if needs be
    def sanitize_parameters(parameters, permit_list)
      # ActionController::Parameters.new(
      #   parameters
      # ).permit(permit_list).to_h
      parameters.slice(*permit_list)
    end

    def association_type(association_reflection)
      case association_reflection.macro
      when :belongs_to, :has_one
        :singular
      when :has_many, :has_and_belongs_to_many
        :collection
      else
        :unknown
      end
    end
  end
end
