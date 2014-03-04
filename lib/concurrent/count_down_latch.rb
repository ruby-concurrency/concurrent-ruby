module Concurrent

  # A synchronization object that allows one thread to wait on multiple other threads.
  # The thread that will wait creates a +CountDownLatch+ and sets the initial value
  # (normally equal to the number of other threads). The initiating thread passes the
  # latch to the other threads then waits for the other threads by calling the +#wait+
  # method. Each of the other threads calls +#count_down+ when done with its work.
  # When the latch counter reaches zero the waiting thread is unblocked and continues
  # with its work. A +CountDownLatch+ can be used only once. Its value cannot be reset.
  class CountDownLatch

    # Create a new +CountDownLatch+ with the initial +count+.
    #
    # @param [Fixnum] count the initial count
    #
    # @raise [ArgumentError] if +count+ is not an integer or is less than zero
    def initialize(count)
      unless count.is_a?(Fixnum) && count >= 0
        raise ArgumentError.new('count must be in integer greater than or equal zero')
      end
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @count = count
    end

    # Block on the latch until the counter reaches zero or until +timeout+ is reached.
    #
    # @param [Fixnum] timeout the number of seconds to wait for the counter or +nil+
    #   to block indefinitely
    # @return [Boolean] +true+ if the +count+ reaches zero else false on +timeout+
    def wait(timeout = nil)
      @mutex.synchronize do
        @condition.wait(@mutex, timeout) if @count > 0
        @count == 0
      end
    end

    # Signal the latch to decrement the counter. Will signal all blocked threads when
    # the +count+ reaches zero.
    def count_down
      @mutex.synchronize do
        @count -= 1 if @count > 0
        @condition.broadcast if @count == 0
      end
    end

    # The current value of the counter.
    #
    # @return [Fixnum] the current value of the counter
    def count
      @mutex.synchronize { @count }
    end

  end
end
