require 'thread'
require 'concurrent/utilities'
require 'concurrent/condition'

module Concurrent

  # Old school kernel-style event reminiscent of Win32 programming in C++.
  #
  # When an +Event+ is created it is in the +unset+ state. Threads can choose to
  # +#wait+ on the event, blocking until released by another thread. When one
  # thread wants to alert all blocking threads it calls the +#set+ method which
  # will then wake up all listeners. Once an +Event+ has been set it remains set.
  # New threads calling +#wait+ will return immediately. An +Event+ may be
  # +#reset+ at any time once it has been set.
  #
  # @see http://msdn.microsoft.com/en-us/library/windows/desktop/ms682655.aspx
  class Event

    # Creates a new +Event+ in the unset state. Threads calling +#wait+ on the
    # +Event+ will block.
    def initialize
      @set = false
      @mutex = Mutex.new
      @condition = Condition.new
    end

    # Is the object in the set state?
    #
    # @return [Boolean] indicating whether or not the +Event+ has been set
    def set?
      @mutex.synchronize do
        @set
      end
    end

    # Trigger the event, setting the state to +set+ and releasing all threads
    # waiting on the event. Has no effect if the +Event+ has already been set.
    #
    # @return [Boolean] should always return +true+
    def set
      @mutex.synchronize do
        return true if @set
        @set = true
        @condition.broadcast
      end

      true
    end

    # Reset a previously set event back to the +unset+ state.
    # Has no effect if the +Event+ has not yet been set.
    #
    # @return [Boolean] should always return +true+
    def reset
      @mutex.synchronize do
        @set = false
      end

      true
    end

    # Wait a given number of seconds for the +Event+ to be set by another
    # thread. Will wait forever when no +timeout+ value is given. Returns
    # immediately if the +Event+ has already been set.
    #
    # @return [Boolean] true if the +Event+ was set before timeout else false
    def wait(timeout = nil)
      @mutex.synchronize do
        return true if @set

        remaining = Condition::Result.new(timeout)
        while !@set && remaining.can_wait?
          remaining = @condition.wait(@mutex, remaining.remaining_time)
        end

        @set
      end
    end
  end
end
