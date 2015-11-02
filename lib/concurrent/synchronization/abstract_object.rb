module Concurrent
  module Synchronization

    # @!visibility private
    # @!macro internal_implementation_note
    class AbstractObject

      # @abstract has to be implemented based on Ruby runtime
      def initialize
        raise NotImplementedError
      end

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
      # @!visibility private
      def ensure_ivar_visibility!
        # We have to prevent ivar writes to reordered with storing of the final instance reference
        # Therefore wee need a fullFence to prevent reordering in both directions.
        full_memory_barrier
      end

      protected

      # @!visibility private
      # @abstract
      def full_memory_barrier
        raise NotImplementedError
      end

      def self.attr_volatile(*names)
        raise NotImplementedError
      end
    end
  end
end
