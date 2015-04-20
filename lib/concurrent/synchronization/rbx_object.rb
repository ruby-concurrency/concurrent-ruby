module Concurrent
  module Synchronization
    if Concurrent.on_rbx?
      class RbxObject < AbstractObject
        def initialize
          @waiters = []
        end

        def synchronize(&block)
          Rubinius.synchronize(self, &block)
        end

        private

        def ns_wait(timeout = nil)
          wchan = Rubinius::Channel.new

          begin
            @waiters.push wchan
            Rubinius.unlock(self)
            signaled = wchan.receive_timeout timeout
          ensure
            Rubinius.lock(self)

            if !signaled && !@waiters.delete(wchan)
              # we timed out, but got signaled afterwards,
              # so pass that signal on to the next waiter
              @waiters.shift << true unless @waiters.empty?
            end
          end

          self
        end

        def ns_signal
          @waiters.shift << true unless @waiters.empty?
          self
        end

        def ns_broadcast
          @waiters.shift << true until @waiters.empty?
          self
        end
      end

      def ensure_ivar_visibility!
        Rubinius.memory_barrier
      end

      def self.attr_volatile *names
        names.each do |name|
          ivar = :"@volatile_#{name}"
          define_method name do
            Rubinius.memory_barrier
            instance_variable_get ivar
          end

          define_method "#{name}=" do |value|
            instance_variable_set ivar, value
            Rubinius.memory_barrier
          end
        end
      end
    end
  end
end
