module Concurrent
  module Synchronization

    module TruffleAttrVolatile
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def attr_volatile(*names)
          # TODO may not always be available
          attr_atomic(*names)
        end
      end

      def full_memory_barrier
        # Rubinius instance variables are not volatile so we need to insert barrier
        Rubinius.memory_barrier
      end
    end

    # @!visibility private
    # @!macro internal_implementation_note
    class TruffleObject < AbstractObject
      include TruffleAttrVolatile

      def initialize
        # nothing to do
      end
    end
  end
end
