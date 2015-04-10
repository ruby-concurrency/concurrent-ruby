module Concurrent

  # Safe synchronization under any Ruby implementation
  # Provides a single layer which can improve its implementation over time without changes needed to
  # the classes using it. Use {SynchronizedObject} not this abstract class.
  # @example
  #   class AnClass < SynchronizedObject
  #     def initialize
  #       super
  #       synchronize { @value = 'asd' }
  #     end
  #
  #     def value
  #       synchronize { @value }
  #     end
  #   end
  class AbstractSynchronizedObject

    # @abstract for helper ivar initialization if needed,
    #     otherwise it can be left empty.
    def initialize
      raise NotImplementedError
    end

    # @yield runs the block synchronized against this object,
    #   equvivalent of java's `synchronize(this) {}`
    def synchronize
      raise NotImplementedError
    end

    private

    # wait until another thread calls #signal or #broadcast,
    # spurious wake-ups can happen.
    # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
    def wait(timeout = nil)
      synchronize { ns_wait(timeout) }
    end

    # Wait until condition is met or timeout passes,
    # protects against spurious wake-ups.
    # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
    # @yield condition to be met
    # @yieldreturn [true, false]
    def wait_until(timeout = nil, &condition)
      synchronize { ns_wait_until(timeout, &condition) }
    end

    # signal one waiting thread
    def signal
      synchronize { ns_signal }
    end

    # broadcast to all waiting threads
    def broadcast
      synchronize { ns_broadcast }
    end

    # @yield condition
    def ns_wait_until(timeout, &condition)
      if timeout
        wait_until = Concurrent.monotonic_time + timeout
        while true
          now              = Concurrent.monotonic_time
          condition_result = condition.call
          # 0.001 correction to avoid error when `wait_until - now` is smaller than 0.0005 and rounded to 0
          # when passed to java #wait(long timeout)
          return condition_result if (now + 0.001) >= wait_until || condition_result
          ns_wait wait_until - now
        end
      else
        ns_wait timeout until condition.call
        true
      end
    end

    def ns_wait(timeout)
      raise NotImplementedError
    end

    def ns_signal
      raise NotImplementedError
    end

    def ns_broadcast
      raise NotImplementedError
    end

  end

  begin
    require 'jruby'

    # roughly more than 2x faster
    class JavaSynchronizedObject < AbstractSynchronizedObject
      def initialize
      end

      def synchronize
        JRuby.reference0(self).synchronized { yield }
      end

      private

      def ns_wait(timeout)
        if timeout
          JRuby.reference0(self).wait(timeout * 1000)
        else
          JRuby.reference0(self).wait
        end
      end

      def ns_broadcast
        JRuby.reference0(self).notifyAll
      end

      def ns_signal
        JRuby.reference0(self).notify
      end
    end
  rescue LoadError
    # ignore
  end

  class MutexSynchronizedObject < AbstractSynchronizedObject
    def initialize
      @__lock__do_not_use_directly      = Mutex.new
      @__condition__do_not_use_directly = ::ConditionVariable.new
    end

    def synchronize
      if @__lock__do_not_use_directly.owned?
        yield
      else
        @__lock__do_not_use_directly.synchronize { yield }
      end
    end

    private

    def ns_signal
      @__condition__do_not_use_directly.signal
    end

    def ns_broadcast
      @__condition__do_not_use_directly.broadcast
    end

    def ns_wait(timeout)
      @__condition__do_not_use_directly.wait @__lock__do_not_use_directly, timeout
    end
  end

  class MonitorSynchronizedObject < MutexSynchronizedObject
    def initialize
      @__lock__do_not_use_directly      = Monitor.new
      @__condition__do_not_use_directly = @__lock__do_not_use_directly.new_cond
    end

    def synchronize
      @__lock__do_not_use_directly.synchronize { yield }
    end

    private

    def ns_wait(timeout)
      @__condition__do_not_use_directly.wait timeout
    end
  end

  # TODO add rbx implementation
  SynchronizedObject = Class.new case
                                 when Concurrent.on_jruby?
                                   JavaSynchronizedObject
                                 when Concurrent.on_cruby? && (RUBY_VERSION.split('.').map(&:to_i) <=> [1, 9, 3]) >= 0
                                   MonitorSynchronizedObject
                                 when Concurrent.on_cruby?
                                   MutexSynchronizedObject
                                 when Concurrent.on_rbx?
                                   # TODO better implementation
                                   MonitorSynchronizedObject
                                 else
                                   MutexSynchronizedObject
                                 end
end
