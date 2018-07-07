if Concurrent.on_jruby?

  module Concurrent

    # @!macro count_down_latch
    # @!visibility private
    # @!macro internal_implementation_note
    class JavaCountDownLatch

      # @!macro count_down_latch_method_initialize
      def initialize(count = 1)
        Utility::NativeInteger.ensure_integer_and_bounds(count)
        Utility::NativeInteger.ensure_positive(count)
        @latch = java.util.concurrent.CountDownLatch.new(count)
      end

      # @!macro count_down_latch_method_wait
      def wait(timeout = nil)
        if timeout.nil?
          Synchronization::JRuby.sleep_interruptibly { @latch.await }
          true
        else
          Synchronization::JRuby.sleep_interruptibly do
            @latch.await(1000 * timeout, java.util.concurrent.TimeUnit::MILLISECONDS)
          end
        end
      end

      # @!macro count_down_latch_method_count_down
      def count_down
        @latch.countDown
      end

      # @!macro count_down_latch_method_count
      def count
        @latch.getCount
      end
    end
  end
end
