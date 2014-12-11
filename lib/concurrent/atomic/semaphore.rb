require 'concurrent/atomic/condition'

module Concurrent
  class MutexSemaphore
    # @!macro [attach] semaphore_method_initialize
    #
    #   Create a new `Semaphore` with the initial `count`.
    #
    #   @param [Fixnum] count the initial count
    #
    #   @raise [ArgumentError] if `count` is not an integer or is less than zero
    def initialize(count)
      unless count.is_a?(Fixnum) && count >= 0
        fail ArgumentError, 'count must be an non-negative integer'
      end
      @mutex = Mutex.new
      @condition = Condition.new
      @free = count
    end

    # @!macro [attach] semaphore_method_acquire
    #
    #   Acquires the given number of permits from this semaphore,
    #     blocking until all are available.
    #
    #   @param [Fixnum] permits Number of permits to acquire
    #
    #   @raise [ArgumentError] if `permits` is not an integer or is less than
    #     one
    #
    #   @return [True]
    def acquire(permits = 1)
      unless permits.is_a?(Fixnum) && permits > 0
        fail ArgumentError, 'permits must be an integer greater than zero'
      end
      @mutex.synchronize do
        try_acquire_timed(permits, nil)
      end
    end

    # @!macro [attach] semaphore_method_available_permits
    #
    #   Returns the current number of permits available in this semaphore.
    #
    #   @return [Integer]
    def available_permits
      @mutex.synchronize { @free }
    end

    # @!macro [attach] semaphore_method_drain_permits
    #
    #   Acquires and returns all permits that are immediately available.
    #
    #   @return [Integer]
    def drain_permits
      @mutex.synchronize do
        @free.tap { |_| @free = 0 }
      end
    end

    # @!macro [attach] semaphore_method_try_acquire
    #
    #   Acquires the given number of permits from this semaphore,
    #     only if all are available at the time of invocation or within
    #     `timeout` interval
    #
    #   @param [Fixnum] permits the number of permits to acquire
    #
    #   @param [Fixnum] timeout the number of seconds to wait for the counter
    #     or `nil` to return immediately
    #
    #   @raise [ArgumentError] if `permits` is not an integer or is less than
    #     one
    #
    #   @return [Boolean] `false` if no permits are available, `true` when
    #     acquired a permit
    def try_acquire(permits = 1, timeout = nil)
      unless permits.is_a?(Fixnum) && permits > 0
        fail ArgumentError, 'permits must be an integer greater than zero'
      end
      @mutex.synchronize do
        if timeout.nil?
          try_acquire_now(permits)
        else
          try_acquire_timed(permits, timeout)
        end
      end
    end

    # @!macro [attach] semaphore_method_release
    #
    #   Releases the given number of permits, returning them to the semaphore.
    #
    #   @param [Fixnum] permits Number of permits to return to the semaphore.
    #
    #   @raise [ArgumentError] if `permits` is not a number or is less than one
    #
    #   @return [True]
    def release(permits = 1)
      unless permits.is_a?(Fixnum) && permits > 0
        fail ArgumentError, 'permits must be an integer greater than zero'
      end
      @mutex.synchronize do
        @free += permits
        permits.times { @condition.signal }
      end
      true
    end

    # @!macro [attach] semaphore_method_reduce_permits
    #
    #   Shrinks the number of available permits by the indicated reduction.
    #
    #   @param [Fixnum] reduction Number of permits to remove.
    #
    #   @raise [ArgumentError] if `reduction` is not an integer or is negative
    #
    #   @raise [ArgumentError] if `@free` - `@reduction` is less than zero
    #
    #   @return [True]
    def reduce_permits(reduction)
      unless reduction.is_a?(Fixnum) && reduction >= 0
        fail ArgumentError, 'reduction must be an non-negative integer'
      end
      unless @free - reduction >= 0
        fail(ArgumentError,
             'cannot reduce number of available_permits below zero')
      end
      @mutex.synchronize { @free -= reduction }
      true
    end

    private

    def try_acquire_now(permits)
      if @free >= permits
        @free -= permits
        true
      else
        false
      end
    end

    def try_acquire_timed(permits, timeout)
      remaining = Condition::Result.new(timeout)
      while !try_acquire_now(permits) && remaining.can_wait?
        @condition.signal
        remaining = @condition.wait(@mutex, remaining.remaining_time)
      end
      remaining.can_wait? ? true : false
    end
  end

  if RUBY_PLATFORM == 'java'

    # @!macro semaphore
    class JavaSemaphore
      # @!macro semaphore_method_initialize
      def initialize(count)
        unless count.is_a?(Fixnum) && count >= 0
          fail(ArgumentError,
               'count must be in integer greater than or equal zero')
        end
        @semaphore = java.util.concurrent.Semaphore.new(count)
      end

      # @!macro semaphore_method_acquire
      def acquire(permits = 1)
        unless permits.is_a?(Fixnum) && permits > 0
          fail ArgumentError, 'permits must be an integer greater than zero'
        end
        @semaphore.acquire(permits)
      end

      # @!macro semaphore_method_available_permits
      def available_permits
        @semaphore.availablePermits
      end

      # @!macro semaphore_method_drain_permits
      def drain_permits
        @semaphore.drainPermits
      end

      # @!macro semaphore_method_try_acquire
      def try_acquire(permits = 1, timeout = nil)
        unless permits.is_a?(Fixnum) && permits > 0
          fail ArgumentError, 'permits must be an integer greater than zero'
        end
        if timeout.nil?
          @semaphore.try_acquire(permits)
        else
          @semaphore.try_acquire(permits,
                                 timeout,
                                 java.util.concurrent.TimeUnit::SECONDS)
        end
      end

      # @!macro semaphore_method_release
      def release(permits = 1)
        unless permits.is_a?(Fixnum) && permits > 0
          fail ArgumentError, 'permits must be an integer greater than zero'
        end
        @semaphore.release(permits)
        true
      end

      # @!macro semaphore_method_reduce_permits
      def reduce_permits(reduction)
        unless reduction.is_a?(Fixnum) && reduction >= 0
          fail ArgumentError, 'reduction must be an non-negative integer'
        end
        unless @free - reduction >= 0
          fail(ArgumentError,
               'cannot reduce number of available_permits below zero')
        end
        @semaphore.reducePermits(void)
      end
    end

    # @!macro semaphore
    class Semaphore < JavaSemaphore
    end

  else

    # @!macro semaphore
    class Semaphore < MutexSemaphore
    end
  end
end
