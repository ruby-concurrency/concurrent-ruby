module Concurrent
  module Synchronization

    if Concurrent.on_jruby?
      require 'jruby'

      class JavaPureObject < AbstractObject
        def initialize(*args, &block)
          synchronize { ns_initialize(*args, &block) }
        end

        private

        def synchronize
          JRuby.reference0(self).synchronized { yield }
        end

        def ns_wait(timeout = nil)
          success = JRuby.reference0(Thread.current).wait_timeout(JRuby.reference0(self), timeout)
          self
        rescue java.lang.InterruptedException => e
          raise ThreadError(e.message)
        ensure
          ns_signal unless success
        end

        def ns_broadcast
          JRuby.reference0(self).notifyAll
          self
        end

        def ns_signal
          JRuby.reference0(self).notify
          self
        end

        def ensure_ivar_visibility!
          # relying on undocumented behavior of JRuby, ivar access is volatile
        end
      end
    end
  end
end
