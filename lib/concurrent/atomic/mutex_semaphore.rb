require 'concurrent/synchronization'

module Concurrent

  # @!macro semaphore
  # @!visibility private
  # @!macro internal_implementation_note
  class MutexSemaphore < Synchronization::LockableObject

    # @!macro semaphore_method_initialize
    def initialize(count)
      unless count.is_a?(Fixnum) && count >= 0
        fail ArgumentError, 'count must be an non-negative integer'
      end
      super()
      synchronize { ns_initialize count }
    end

    # @!macro semaphore_method_acquire
    def acquire(permits = 1)
      unless permits.is_a?(Fixnum) && permits > 0
        fail ArgumentError, 'permits must be an integer greater than zero'
      end
      synchronize do
        try_acquire_timed(permits, nil)
        nil
      end
    end

    # @!macro semaphore_method_available_permits
    def available_permits
      synchronize { @free }
    end

    # @!macro semaphore_method_drain_permits
    #
    #   Acquires and returns all permits that are immediately available.
    #
    #   @return [Integer]
    def drain_permits
      synchronize do
        @free.tap { |_| @free = 0 }
      end
    end

    # @!macro semaphore_method_try_acquire
    def try_acquire(permits = 1, timeout = nil)
      unless permits.is_a?(Fixnum) && permits > 0
        fail ArgumentError, 'permits must be an integer greater than zero'
      end
      synchronize do
        if timeout.nil?
          try_acquire_now(permits)
        else
          try_acquire_timed(permits, timeout)
        end
      end
    end

    # @!macro semaphore_method_release
    def release(permits = 1)
      unless permits.is_a?(Fixnum) && permits > 0
        fail ArgumentError, 'permits must be an integer greater than zero'
      end
      synchronize do
        @free += permits
        permits.times { ns_signal }
      end
      nil
    end

    # Shrinks the number of available permits by the indicated reduction.
    #
    # @param [Fixnum] reduction Number of permits to remove.
    #
    # @raise [ArgumentError] if `reduction` is not an integer or is negative
    #
    # @raise [ArgumentError] if `@free` - `@reduction` is less than zero
    #
    # @return [nil]
    #
    # @!visibility private
    def reduce_permits(reduction)
      unless reduction.is_a?(Fixnum) && reduction >= 0
        fail ArgumentError, 'reduction must be an non-negative integer'
      end
      synchronize { @free -= reduction }
      nil
    end

    protected

    # @!visibility private
    def ns_initialize(count)
      @free = count
    end

    private

    # @!visibility private
    def try_acquire_now(permits)
      if @free >= permits
        @free -= permits
        true
      else
        false
      end
    end

    # @!visibility private
    def try_acquire_timed(permits, timeout)
      ns_wait_until(timeout) { try_acquire_now(permits) }
    end
  end
end
