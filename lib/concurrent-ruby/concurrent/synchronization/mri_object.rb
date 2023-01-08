module Concurrent
  module Synchronization

    # @!visibility private
    module MriAttrVolatile
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def attr_volatile(*names)
          names.each do |name|
            ivar = :"@volatile_#{name}"
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{name}
                #{ivar}
              end

              def #{name}=(value)
                #{ivar} = value
              end
            RUBY
          end
          names.map { |n| [n, :"#{n}="] }.flatten
        end
      end
    end

  end
end
