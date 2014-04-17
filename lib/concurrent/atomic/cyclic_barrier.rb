module Concurrent

  class CyclicBarrier

    Generation = Struct.new(:status)
    private_constant :Generation

    # Create a new `CyclicBarrier` that waits for `parties` threads
    #
    # @param [Fixnum] parties the number of parties
    # @yield an optional block that will be executed that will be executed after the last thread arrives and before the others are released
    #
    # @raise [ArgumentError] if `parties` is not an integer or is less than zero
    def initialize(parties, &block)
      raise ArgumentError.new('count must be in integer greater than or equal zero') if !parties.is_a?(Fixnum) || parties < 1
      @parties = parties
      @mutex = Mutex.new
      @condition = Condition.new
      @number_waiting = 0
      @action = block
      @generation = Generation.new(:waiting)
    end

    # @return [Fixnum] the number of threads needed to pass the barrier
    def parties
      @parties
    end

    # @return [Fixnum] the number of threads currently waiting on the barrier
    def number_waiting
      @number_waiting
    end

    # Blocks on the barrier until the number of waiting threads is equal to `parties` or until `timeout` is reached or `reset` is called
    # If a block has been passed to the constructor, it will be executed once by the last arrived thread before releasing the others
    # @param [Fixnum] timeout the number of seconds to wait for the counter or `nil` to block indefinitely
    # @return [Boolean] `true` if the `count` reaches zero else false on `timeout` or on `reset` or if the barrier is broken
    def wait(timeout = nil)
      @mutex.synchronize do

        return false unless @generation.status == :waiting

        @number_waiting += 1

        if @number_waiting == @parties
          @action.call if @action
          set_status_and_restore(:fulfilled)
          true
        else
          wait_for_wake_up(@generation, timeout)
        end
      end
    end



    # resets the barrier to its initial state
    # If there is at least one waiting thread, it will be woken up, the `wait` method will return false and the barrier will be broken
    # If the barrier is broken, this method restores it to the original state
    #
    # @return [nil]
    def reset
      @mutex.synchronize do
        set_status_and_restore(:reset)
      end
    end

    # A barrier can be broken when:
    # - a thread called the `reset` method while at least one other thread was waiting
    # - at least one thread timed out on `wait` method
    #
    # A broken barrier can be restored using `reset` it's safer to create a new one
    # @return [Boolean] true if the barrier is broken otherwise false
    def broken?
      @mutex.synchronize { @generation.status != :waiting }
    end

    private

    def set_status_and_restore(new_status)
      @generation.status = new_status
      @condition.broadcast
      @generation = Generation.new(:waiting)
      @number_waiting = 0
    end

    def wait_for_wake_up(generation, timeout)
      if wait_while_waiting(generation, timeout)
        generation.status == :fulfilled
      else
        generation.status = :broken
        @condition.broadcast
        false
      end
    end

    def wait_while_waiting(generation, timeout)
      remaining = Condition::Result.new(timeout)
      while generation.status == :waiting && remaining.can_wait?
        remaining = @condition.wait(@mutex, remaining.remaining_time)
      end
      remaining.woken_up?
    end

  end
end