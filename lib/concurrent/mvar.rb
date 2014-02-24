require 'concurrent/event'

module Concurrent

  class MVar

    EMPTY = Object.new
    TIMEOUT = Object.new

    def initialize(value=EMPTY)
      @value = value
      @mutex = Mutex.new
      @empty_condition = ConditionVariable.new
      @full_condition = ConditionVariable.new
    end

    def take(timeout = nil)
      @mutex.synchronize do
        # If the value isn't empty, wait for full to be signalled
        @full_condition.wait(@mutex, timeout) if empty?

        # If we timed out we'll still be empty
        if full?
          value = @value
          @value = EMPTY
          @empty_condition.signal
          value
        else
          TIMEOUT
        end
      end

      
    end

    def put(value, timeout = nil)
      @mutex.synchronize do
        # Unless the value is empty, wait for empty to be signalled
        @empty_condition.wait(@mutex, timeout) if full?

        # If we timed out we won't be empty
        if empty?
          @value = value
          @full_condition.signal
          value
        else
          TIMEOUT
        end
      end
    end

    def empty?
      @value == EMPTY
    end

    def full?
      not empty?
    end

  end

end
