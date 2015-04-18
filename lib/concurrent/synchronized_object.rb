require 'concurrent/utility/engine'

module Concurrent

  # Safe synchronization under any Ruby implementation.
  # It provides methods like {#synchronize}, {#wait}, {#signal} and {#broadcast}.
  # Provides a single layer which can improve its implementation over time without changes needed to
  # the classes using it. Use {SynchronizedObject} not this abstract class.
  #
  # @note this object does not support usage together with {Thread#wakeup} and {Thread#raise}.
  #   `Thread#sleep` and `Thread#wakeup` will work as expected but mixing `SynchronizedObject#wait` and
  #   `Thread#wakeup` will not work on all platforms.
  #
  # @see {Event} implementation as an example of this class use
  #
  # @example simple
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
    # @return [self]
    def wait(timeout = nil)
      synchronize { ns_wait(timeout) }
      self
    end

    # Wait until condition is met or timeout passes,
    # protects against spurious wake-ups.
    # @param [Numeric, nil] timeout in seconds, `nil` means no timeout
    # @yield condition to be met
    # @yieldreturn [true, false]
    # @return [true, false]
    def wait_until(timeout = nil, &condition)
      synchronize { ns_wait_until(timeout, &condition) }
    end

    # signal one waiting thread
    # @return [self]
    def signal
      synchronize { ns_signal }
      self
    end

    # broadcast to all waiting threads
    # @return [self]
    def broadcast
      synchronize { ns_broadcast }
      self
    end

    # @yield condition
    def ns_wait_until(timeout, &condition)
      if timeout
        wait_until = Concurrent.monotonic_time + timeout
        loop do
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

    # @return [self]
    def ns_wait(timeout = nil)
      raise NotImplementedError
    end

    # @return [self]
    def ns_signal
      raise NotImplementedError
    end

    # @return [self]
    def ns_broadcast
      raise NotImplementedError
    end

  end

  require 'concurrent/extension_helper' # FIXME weird order

  if Concurrent.on_jruby?
    require 'jruby'

    class JavaPureSynchronizedObject < AbstractSynchronizedObject
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
      self
    end

    def ns_broadcast
      @__condition__do_not_use_directly.broadcast
      self
    end

    def ns_wait(timeout = nil)
      @__condition__do_not_use_directly.wait @__lock__do_not_use_directly, timeout
      self
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

    def ns_wait(timeout = nil)
      @__condition__do_not_use_directly.wait timeout
      self
    end
  end

  if Concurrent.on_rbx?
    class RbxSynchronizedObject < AbstractSynchronizedObject
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
  end

  class SynchronizedObject < case
                             when Concurrent.on_jruby?
                               JavaSynchronizedObject
                             when Concurrent.on_cruby? && (RUBY_VERSION.split('.').map(&:to_i) <=> [1, 9, 3]) >= 0
                               MonitorSynchronizedObject
                             when Concurrent.on_cruby?
                               MutexSynchronizedObject
                             when Concurrent.on_rbx?
                               RbxSynchronizedObject
                             else
                               MutexSynchronizedObject
                             end
  end
end
