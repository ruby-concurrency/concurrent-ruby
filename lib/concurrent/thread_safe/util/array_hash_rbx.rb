require 'concurrent/thread_safe/util'

module Concurrent
  module ThreadSafe
    module Util
      def self.make_synchronized_on_rbx(klass)
        klass.class_eval do
          private
          def _mon_initialize
            @_monitor = Monitor.new unless @_monitor # avoid double initialisation
          end

          def initialize(*args)
            _mon_initialize
            super
          end

          def self.allocate
            obj = super
            obj.send(:_mon_initialize)
            obj
          end

          def self.[](*args)
            obj = super
            obj.send(:_mon_initialize)
            obj
          end
        end

        klass.superclass.instance_methods(false).each do |method|
          case method
          when :new_range, :new_reserved
            klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(*args)
                obj = super
                obj.send(:_mon_initialize)
                obj
              end
            RUBY
          else
            klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(*args)
                monitor = @_monitor

                unless monitor
                  raise("BUG: Internal monitor was not properly initialized. Please report this to the "\
                    "concurrent-ruby developers.")
                end

                monitor.synchronize { super }
              end
            RUBY
          end
        end
      end
    end
  end
end
