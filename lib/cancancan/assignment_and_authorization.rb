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
      if CanCanCan::NestedAssignmentAndAuthorization.configuration.use_resource_key_in_params
        @params = @params[parent_object.model_name.singular.to_sym]
      end
      if @params.kind_of?(ActionController::Parameters)
        @params = @params.permit!.to_h
      end
      @action_name = action_name.to_sym
    end

    def call
      # Pre-assignment auth check
      first_authorize = @ability.can?(@action_name, @parent_object)
      unless first_authorize || CanCanCan::NestedAssignmentAndAuthorization.configuration.silence_raised_errors
        raise CanCan::AccessDenied.new("Not authorized!", @action_name, @parent_object)
      end

      return false unless first_authorize

      second_authorize = false

      # sanitized_attribs = ActionController::Parameters.new(
      #   @params
      # ).permit(@ability.permitted_attributes(@action_name, @parent_object))

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
          sanitize_parameters(sanitized_attribs, @parent_object.class.nested_attributes_options.keys.collect { |v| "#{v}_attributes".to_sym })
        )
        # Post-assignment auth check
        second_authorize = @ability.can?(@action_name, @parent_object)
        unless second_authorize
          # NOTE: Does not halt the controller process, just rolls back the DB
          raise ActiveRecord::Rollback
        end
      end

      unless second_authorize || CanCanCan::NestedAssignmentAndAuthorization.configuration.silence_raised_errors
        raise CanCan::AccessDenied.new("Not authorized!", @action_name, @parent_object)
      end

      return false unless second_authorize

      save_result = @parent_object.save
      return save_result
    end

    private

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
        assoc_klass = reflection.klass

        if assoc_type == :collection
          param_attribs[param_key].each do |attribs|
            child = save_child_and_child_associations(parent, reflection, nested_attrib_key, attribs)
            next unless child
            parent.send(nested_attrib_key).send(:<<, child)
          end
        elsif assoc_type == :singular
          attribs = param_attribs[param_key]
          child = save_child_and_child_associations(parent, reflection, nested_attrib_key, attribs)
          parent.send("#{nested_attrib_key}=", child) if child
        else
          # unknown, do nothing
        end
      end

    end

    # NOT RECURSIVE
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
      return nil unless child

      sanitized_attribs = sanitize_parameters(attribs, @ability.permitted_attributes(child_action, child))
      sanitized_attribs = sanitize_parameters(sanitized_attribs, assoc_klass.nested_attributes_options.keys.collect { |v| "#{v}_attributes".to_sym })

      # recursive call
      instantiate_and_assign_nested_associations(
        child,
        sanitized_attribs
      )
      return child
    end

    # NOT RECURSIVE!
    def save_child parent, reflection, nested_attrib_key, attribs
      # Check permission on parent
      assoc_klass = reflection.klass
      assoc_primary_key = reflection.options[:primary_key]&.to_sym
      assoc_primary_key ||= :id if assoc_klass.column_names.include?('id')
      assignment_exceptions = [
        :id,
        :_destroy,
        assoc_primary_key
      ] + assoc_klass.nested_attributes_options.keys.collect{ |v| "#{v}_attributes".to_sym }

      # Had issues with nested records on other root objects not being able to be updated to be nested under this root object
      if attribs[assoc_primary_key].present?
        child = assoc_klass.where(assoc_primary_key => attribs[assoc_primary_key]).first
      end
      child ||= parent.send(nested_attrib_key).find_or_initialize_by(assoc_primary_key => attribs[assoc_primary_key])

      child_action = @action_name if !CanCanCan::NestedAssignmentAndAuthorization.configuration.use_smart_nested_authorizations
      child_action ||= :destroy if reflection.options[:allow_destroy] && ['1', 1, true].include?(attribs[:_destroy])
      child_action ||= :create if child.new_record?
      child_action ||= :update

      # Pre-assignment auth check
      first_authorize = @ability.can?(child_action, child)
      unless first_authorize || CanCanCan::NestedAssignmentAndAuthorization.configuration.silence_raised_errors
        # TODO if debug
        # puts "CanCan::AccessDenied.new('Not authorized!', #{child_action}, #{child.class.name})"
        raise CanCan::AccessDenied.new("Not authorized!", child_action, child)
      end

      unless first_authorize
        parent.send(nested_attrib_key).delete(child)
        return nil
      end

      sanitized_attribs = sanitize_parameters(attribs, @ability.permitted_attributes(child_action, child))

      second_authorize = false
      ActiveRecord::Base.transaction do
        child.assign_attributes(sanitized_attribs.except(*assignment_exceptions))
        # Post-assignment auth check
        second_authorize = @ability.can?(child_action, child)
        unless second_authorize
          # NOTE: Does not halt the controller process, just rolls back the DB
          raise ActiveRecord::Rollback
        end
      end

      unless second_authorize || CanCanCan::NestedAssignmentAndAuthorization.configuration.silence_raised_errors
        raise CanCan::AccessDenied.new("Not authorized!", child_action, child)
      end

      unless second_authorize
        parent.send(nested_attrib_key).delete(child)
        return nil
      end

      return child, child_action
    end

    # Can be overridden if needs be
    def sanitize_parameters parameters, permit_list
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
