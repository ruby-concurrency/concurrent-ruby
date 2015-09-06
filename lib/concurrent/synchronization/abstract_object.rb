module Concurrent
  module Synchronization

    # @!macro synchronization_object
    # @!visibility private
    class AbstractObject

      # @!macro [attach] synchronization_object_method_initialize
      #
      #   @abstract has to be called by children
      def initialize
        raise NotImplementedError
      end

      protected

      # @!macro [attach] synchronization_object_method_ensure_ivar_visibility
      #
      #   Allows to construct immutable objects where all fields are visible after initialization, not requiring
      #   further synchronization on access.
      #   @example
      #     class AClass
      #       attr_reader :val
      #       def initialize(val)
      #         @val = val # final value, after assignment it's not changed (just convention, not enforced)
      #         ensure_ivar_visibility!
      #         # now it can be shared as Java's final field
      #       end
      #     end
      def ensure_ivar_visibility!
        # We have to prevent ivar writes to reordered with storing of the final instance reference
        # Therefore wee need a fullFence to prevent reordering in both directions.
        full_memory_barrier
      end

      def full_memory_barrier
        raise NotImplementedError
      end

      # @!macro [attach] synchronization_object_method_self_attr_volatile
      #
      #   creates methods for reading and writing to a instance variable with volatile (Java semantic) instance variable
      #   return [Array<Symbol>] names of defined method names
      def self.attr_volatile(*names)
        raise NotImplementedError
      end
    end
  end
end
