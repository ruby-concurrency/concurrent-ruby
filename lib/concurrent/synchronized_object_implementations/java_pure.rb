module Concurrent
  module SynchronizedObjectImplementations

    if Concurrent.on_jruby?
      require 'jruby'

      class JavaPure < Abstract
        def initialize
        end

        def synchronize
          JRuby.reference0(self).synchronized { yield }
        end

        private

        def ns_wait(timeout = nil)
          success = JRuby.reference0(Thread.current).wait_timeout(JRuby.reference0(self), timeout)
          self
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
      end
    end
  end
end
