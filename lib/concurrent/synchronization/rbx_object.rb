module Concurrent
  module Synchronization

    # @!visibility private
    # @!macro internal_implementation_note
    class RbxObject < AbstractObject
      def initialize
        # nothing to do
      end

      def full_memory_barrier
        # Rubinius instance variables are not volatile so we need to insert barrier
        Rubinius.memory_barrier
      end

      def self.attr_volatile *names
        names.each do |name|
          ivar = :"@volatile_#{name}"
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              Rubinius.memory_barrier
              #{ivar}
            end

            def #{name}=(value)
              #{ivar} = value
              Rubinius.memory_barrier
            end
          RUBY
        end
        names.map { |n| [n, :"#{n}="] }.flatten
      end
    end

  end
end
