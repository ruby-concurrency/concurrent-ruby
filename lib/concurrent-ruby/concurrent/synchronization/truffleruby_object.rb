module Concurrent
  module Synchronization

    # @!visibility private
    module TruffleRubyAttrVolatile
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def attr_volatile(*names)
          names.each do |name|
            ivar = :"@volatile_#{name}"

            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{name}
                ::Concurrent::Synchronization.full_memory_barrier
                #{ivar}                  
              end

              def #{name}=(value)
                #{ivar} = value
                ::Concurrent::Synchronization.full_memory_barrier
              end
            RUBY
          end

          names.map { |n| [n, :"#{n}="] }.flatten
        end
      end
    end

  end
end
