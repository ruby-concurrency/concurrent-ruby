require 'concurrent/event'

module Concurrent

  class MVar

    include Dereferenceable

    EMPTY = Object.new
    TIMEOUT = Object.new

    def initialize(value = EMPTY, opts = {})
      @value = value
      @mutex = Mutex.new
      @empty_condition = ConditionVariable.new
      @full_condition = ConditionVariable.new
      set_deref_options(opts)
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
          apply_deref_options(value)
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
          apply_deref_options(value)
        else
          TIMEOUT
        end
      end
    end

    def modify(timeout = nil)
      raise ArgumentError.new('no block given') unless block_given?

      @mutex.synchronize do
        # If the value isn't empty, wait for full to be signalled
        @full_condition.wait(@mutex, timeout) if empty?

        # If we timed out we'll still be empty
        if full?
          value = @value
          @value = yield value
          @full_condition.signal
          apply_deref_options(value)
        else
          TIMEOUT
        end
      end
    end

    def try_take!
      @mutex.synchronize do
        if full?
          value = @value
          @value = EMPTY
          @empty_condition.signal
          apply_deref_options(value)
        else
          EMPTY
        end
      end
    end

    def try_put!(value)
      @mutex.synchronize do
        if empty?
          @value = value
          @full_condition.signal
          true
        else
          false
        end
      end
    end

    def set!(value)
      @mutex.synchronize do
        old_value = @value
        @value = value
        @full_condition.signal
        apply_deref_options(old_value)
      end
    end

    def modify!(timeout = nil)
      raise ArgumentError.new('no block given') unless block_given?

      @mutex.synchronize do
        value = @value
        @value = yield value
        if @value == EMPTY
          @empty_condition.signal
        else
          @full_condition.signal
        end
        apply_deref_options(value)
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
