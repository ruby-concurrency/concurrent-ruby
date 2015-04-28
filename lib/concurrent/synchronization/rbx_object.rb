module Concurrent
  module Synchronization
    if Concurrent.on_rbx?
      class RbxObject < AbstractObject
        def initialize(*args, &block)
          synchronize do
            @waiters = []
            ns_initialize(*args, &block)
          end
        end

        private

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
      end
    end
  end
end
