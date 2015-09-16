require 'concurrent/synchronization'

module Concurrent

  # @!macro count_down_latch
  # @!visibility private
  # @!macro internal_implementation_note
  class MutexCountDownLatch < Synchronization::LockableObject

    # @!macro count_down_latch_method_initialize
    def initialize(count = 1)
      unless count.is_a?(Fixnum) && count >= 0
        raise ArgumentError.new('count must be in integer greater than or equal zero')
      end
      super()
      synchronize { ns_initialize count }
    end

    # @!macro count_down_latch_method_wait
    def wait(timeout = nil)
      synchronize { ns_wait_until(timeout) { @count == 0 } }
    end

    # @!macro count_down_latch_method_count_down
    def count_down
      synchronize do
        @count -= 1 if @count > 0
        ns_broadcast if @count == 0
      end
    end

    # @!macro count_down_latch_method_count
    def count
      synchronize { @count }
    end

    protected

    def ns_initialize(count)
      @count = count
    end
  end
end
