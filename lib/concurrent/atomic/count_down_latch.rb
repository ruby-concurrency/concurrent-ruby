require 'concurrent/atomic/condition'

module Concurrent

  # @!macro [attach] count_down_latch
  #
  #   A synchronization object that allows one thread to wait on multiple other threads.
  #   The thread that will wait creates a `CountDownLatch` and sets the initial value
  #   (normally equal to the number of other threads). The initiating thread passes the
  #   latch to the other threads then waits for the other threads by calling the `#wait`
  #   method. Each of the other threads calls `#count_down` when done with its work.
  #   When the latch counter reaches zero the waiting thread is unblocked and continues
  #   with its work. A `CountDownLatch` can be used only once. Its value cannot be reset.
  class MutexCountDownLatch

    # @!macro [attach] count_down_latch_method_initialize
    #
    #   Create a new `CountDownLatch` with the initial `count`.
    #
    #   @param [Fixnum] count the initial count
    #
    #   @raise [ArgumentError] if `count` is not an integer or is less than zero
    def initialize(count)
      unless count.is_a?(Fixnum) && count >= 0
        raise ArgumentError.new('count must be in integer greater than or equal zero')
      end
      @mutex = Mutex.new
      @condition = Condition.new
      @count = count
    end

    # @!macro [attach] count_down_latch_method_wait
    #
    #   Block on the latch until the counter reaches zero or until `timeout` is reached.
    #
    #   @param [Fixnum] timeout the number of seconds to wait for the counter or `nil`
    #     to block indefinitely
    #   @return [Boolean] `true` if the `count` reaches zero else false on `timeout`
    def wait(timeout = nil)
      @mutex.synchronize do

        remaining = Condition::Result.new(timeout)
        while @count > 0 && remaining.can_wait?
          remaining = @condition.wait(@mutex, remaining.remaining_time)
        end

        @count == 0
      end
    end

    # @!macro [attach] count_down_latch_method_count_down
    #
    #   Signal the latch to decrement the counter. Will signal all blocked threads when
    #   the `count` reaches zero.
    def count_down
      @mutex.synchronize do
        @count -= 1 if @count > 0
        @condition.broadcast if @count == 0
      end
    end

    # @!macro [attach] count_down_latch_method_count
    #
    #   The current value of the counter.
    #
    #   @return [Fixnum] the current value of the counter
    def count
      @mutex.synchronize { @count }
    end
  end

  if RUBY_PLATFORM == 'java'

    # @!macro count_down_latch
    class JavaCountDownLatch

      # @!macro count_down_latch_method_initialize
      def initialize(count)
        unless count.is_a?(Fixnum) && count >= 0
          raise ArgumentError.new('count must be in integer greater than or equal zero')
        end
        @latch = java.util.concurrent.CountDownLatch.new(count)
      end

      # @!macro count_down_latch_method_wait
      def wait(timeout = nil)
        if timeout.nil?
          @latch.await
          true
        else
          @latch.await(1000 * timeout, java.util.concurrent.TimeUnit::MILLISECONDS)
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

    # @!macro count_down_latch
    class CountDownLatch < JavaCountDownLatch
    end

  else

    # @!macro count_down_latch
    class CountDownLatch < MutexCountDownLatch
    end
  end
end
