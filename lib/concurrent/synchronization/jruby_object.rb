module Concurrent
  module Synchronization

    if Concurrent.on_jruby?

      # @!visibility private
      # @!macro internal_implementation_note
      class JRubyObject < AbstractObject

        def initialize
          # nothing to do
        end

        def self.attr_volatile(*names)
          names.each do |name|

            ivar = :"@volatile_#{name}"

            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{name}
                instance_variable_get_volatile(:#{ivar})
              end

              def #{name}=(value)
                instance_variable_set_volatile(:#{ivar}, value)
              end
            RUBY

          end
          names.map { |n| [n, :"#{n}="] }.flatten
        end

      end
    end
  end
end
