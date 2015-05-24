module Concurrent
  module Synchronization
    if Concurrent.on_rbx?
      class RbxObject < AbstractObject
        def initialize(*args, &block)
          @waiters = []
          ensure_ivar_visibility!
        end

        protected

        def synchronize(&block)
          Rubinius.synchronize(self, &block)
        end

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

        def ensure_ivar_visibility!
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
end
