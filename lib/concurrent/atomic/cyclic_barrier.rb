module Concurrent

  class CyclicBarrier

    # Create a new `CyclicBarrier` that waits for `parties` threads
    #
    # @param [Fixnum] parties the number of parties
    # @yield an optional block that will be executed that will be executed after the last thread arrives and before the others are released
    #
    # @raise [ArgumentError] if `parties` is not an integer or is less than zero
    def initialize(parties)
    end

    # @return [Fixnum] the number of threads needed to pass the barrier
    def parties
    end

    # @return [Fixnum] the number of threads currently waiting on the barrier
    def number_waiting
    end

    # Blocks on the barrier until the number of waiting threads is equal to `parties` or until `timeout` is reached or `reset` is called
    # @param [Fixnum] timeout the number of seconds to wait for the counter or `nil` to block indefinitely
    # @return [Boolean] `true` if the `count` reaches zero else false on `timeout` or on `reset`
    def wait(timeout = nil)
    end

    # resets the barrier to its initial state
    # If there is at least one waiting thread, it will be woken up, the `wait` method will return false and the barrier will be broken
    #
    # @return [nil]
    def reset
    end

    # A barrier can be broken when:
    # - a thread called the `reset` method while at least one thread was waiting
    # - at least one thread timed out on `wait` method
    #
    # A broken barrier cannot be restored and it should not be reused: it's safer to create a new one
    # @return [Boolean] true if the barrier is broken otherwise false
    def broken?
    end

  end
end