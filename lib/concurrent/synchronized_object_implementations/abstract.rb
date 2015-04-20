module Concurrent
  module SynchronizedObjectImplementations
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
    class Abstract

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
      # @note intended to be made public if required in child classes
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
      # @note intended to be made public if required in child classes
      def wait_until(timeout = nil, &condition)
        synchronize { ns_wait_until(timeout, &condition) }
      end

      # signal one waiting thread
      # @return [self]
      # @note intended to be made public if required in child classes
      def signal
        synchronize { ns_signal }
        self
      end

      # broadcast to all waiting threads
      # @return [self]
      # @note intended to be made public if required in child classes
      def broadcast
        synchronize { ns_broadcast }
        self
      end

      # @note only to be used inside synchronized block
      # @yield condition
      # @return [true, false]
      # see #wait_until
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

      # @note only to be used inside synchronized block
      # @return [self]
      # @see #wait
      def ns_wait(timeout = nil)
        raise NotImplementedError
      end

      # @note only to be used inside synchronized block
      # @return [self]
      # @see #signal
      def ns_signal
        raise NotImplementedError
      end

      # @note only to be used inside synchronized block
      # @return [self]
      # @see #broadcast
      def ns_broadcast
        raise NotImplementedError
      end
    end
  end
end
