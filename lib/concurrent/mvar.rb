require 'concurrent/dereferenceable'
require 'concurrent/atomic/condition'
require 'concurrent/atomic/event'

module Concurrent

  class MVar

    include Dereferenceable

    EMPTY = Object.new
    TIMEOUT = Object.new

    def initialize(value = EMPTY, opts = {})
      @value = value
      @mutex = Mutex.new
      @empty_condition = Condition.new
      @full_condition = Condition.new
      set_deref_options(opts)
    end

    def take(timeout = nil)
      @mutex.synchronize do
        wait_for_full(timeout)

        # If we timed out we'll still be empty
        if unlocked_full?
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
        wait_for_empty(timeout)

        # If we timed out we won't be empty
        if unlocked_empty?
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
        wait_for_full(timeout)

        # If we timed out we'll still be empty
        if unlocked_full?
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
        if unlocked_full?
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
        if unlocked_empty?
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

    def modify!
      raise ArgumentError.new('no block given') unless block_given?

      @mutex.synchronize do
        value = @value
        @value = yield value
        if unlocked_empty?
          @empty_condition.signal
        else
          @full_condition.signal
        end
        apply_deref_options(value)
      end
    end

    def empty?
      @mutex.synchronize { @value == EMPTY }
    end

    def full?
      not empty?
    end

    private

    def unlocked_empty?
      @value == EMPTY
    end

    def unlocked_full?
      ! unlocked_empty?
    end

    def wait_for_full(timeout)
      wait_while(@full_condition, timeout) { unlocked_empty? }
    end

    def wait_for_empty(timeout)
      wait_while(@empty_condition, timeout) { unlocked_full? }
    end

    def wait_while(condition, timeout)
      remaining = Condition::Result.new(timeout)
      while yield && remaining.can_wait?
        remaining = condition.wait(@mutex, remaining.remaining_time)
      end
    end

  end

end
