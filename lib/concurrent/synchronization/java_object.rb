require 'concurrent/native_extensions' # load native part first

module Concurrent
  module Synchronization

    if Concurrent.on_jruby?
      require 'jruby'

      class JavaObject < AbstractObject

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
