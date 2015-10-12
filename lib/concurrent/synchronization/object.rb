module Concurrent
  module Synchronization

    # @!visibility private
    # @!macro internal_implementation_note
    ObjectImplementation = case
                           when Concurrent.on_cruby?
                             MriObject
                           when defined? JRubyObject
                             JRubyObject
                           when Concurrent.on_rbx?
                             RbxObject
                           else
                             warn 'Possibly unsupported Ruby implementation'
                             MriObject
                           end
    private_constant :ObjectImplementation

    # TODO fix documentation
    # @!macro [attach] synchronization_object
    #
    #   Safe synchronization under any Ruby implementation.
    #   It provides methods like `#synchronize`, `#wait`, `#signal` and `#broadcast`.
    #   Provides a single layer which can improve its implementation over time without changes needed to
    #   the classes using it. Use {Synchronization::Object} not this abstract class.
    #
    #   @note this object does not support usage together with
    #     [`Thread#wakeup`](http://ruby-doc.org/core-2.2.0/Thread.html#method-i-wakeup)
    #     and [`Thread#raise`](http://ruby-doc.org/core-2.2.0/Thread.html#method-i-raise).
    #     `Thread#sleep` and `Thread#wakeup` will work as expected but mixing `Synchronization::Object#wait` and
    #     `Thread#wakeup` will not work on all platforms.
    #
    #   @see {Event} implementation as an example of this class use
    #
    #   @example simple
    #     class AnClass < Synchronization::Object
    #       def initialize
    #         super
    #         synchronize { @value = 'asd' }
    #       end
    #
    #       def value
    #         synchronize { @value }
    #       end
    #     end
    #
    class Object < ObjectImplementation

      # Has to be called by children.
      # Initializes default volatile fields with cas if any.
      # @param [Array<Object>] defaults values for fields, in same order as they are defined
      def initialize(*defaults)
        super()
        initialize_volatile_cas_fields(defaults)
      end

      # By calling this method on a class, it and all its children are marked to be constructed safely. Meaning that
      # all writes (ivar initializations) are made visible to all readers of newly constructed object. It ensures
      # same behaviour as Java's final fields.
      # @example
      #   class AClass < Concurrent::Synchronization::Object
      #     safe_initialization!
      #
      #     def initialize
      #       @AFinalValue = 'value' # published safly, does not have to be synchronized
      #     end
      #   end
      def self.safe_initialization!
        # define only once, and not again in children
        return if safe_initialization?

        def self.new(*)
          object = super
        ensure
          object.ensure_ivar_visibility! if object
        end

        @safe_initialization = true
      end

      def self.safe_initialization?
        (defined?(@safe_initialization) && @safe_initialization) || (superclass.respond_to?(:safe_initialization?) && superclass.safe_initialization?)
      end

      # For testing purposes, quite slow.
      def self.ensure_safe_initialization_when_final_fields_are_present
        Object.class_eval do
          def self.new(*)
            object = super
          ensure
            has_final_field = object.instance_variables.any? { |v| v.to_s =~ /^@[A-Z]/ }
            if has_final_field && !safe_initialization?
              raise "there was an instance of #{object.class} with final field but not marked with safe_initialization!"
            end
          end
        end
      end

      # TODO documentation
      def self.attr_volatile_with_cas(*names)
        @volatile_cas_fields ||= []
        @volatile_cas_fields += names
        safe_initialization!

        names.each do |name|
          ivar = :"@VolatileCas_#{name}"
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              #{ivar}.get
            end

            def #{name}=(value)
              #{ivar}.set value
            end

            def swap_#{name}(value)
              #{ivar}.swap value
            end

            def compare_and_set_#{name}(expected, value)
              #{ivar}.compare_and_set expected, value
            end

            def update_#{name}(&block)
              #{ivar}.update(&block)
            end
          RUBY
        end
        names.map { |n| [n, :"#{n}=", :"swap_#{n}", :"compare_and_set_#{n}"] }.flatten
      end

      def self.volatile_cas_fields(inherited = true)
        # TODO (pitr 11-Sep-2015): maybe use constant for better optimisation on Truffle since it will not speculate on ivar being final
        @volatile_cas_fields ||= []
        ((superclass.volatile_cas_fields if superclass.respond_to?(:volatile_cas_fields) && inherited) || []) +
            @volatile_cas_fields
      end

      private

      def initialize_volatile_cas_fields(defaults)
        self.class.volatile_cas_fields.zip(defaults) do |name, default|
          instance_variable_set :"@VolatileCas_#{name}", AtomicReference.new(default)
        end
        nil
      end

      # @!method ensure_ivar_visibility!
      #   @!macro synchronization_object_method_ensure_ivar_visibility

      # @!method self.attr_volatile(*names)
      #   @!macro synchronization_object_method_self_attr_volatile
    end
  end
end
