require 'concurrent/native_extensions' # load native part first

module Concurrent
  module Synchronization

    if Concurrent.on_jruby?
      require 'jruby'

      unless org.jruby.util.unsafe.UnsafeHolder::SUPPORTS_FENCES
        raise 'java7 is not supported at the moment, please use java8'
      end

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
