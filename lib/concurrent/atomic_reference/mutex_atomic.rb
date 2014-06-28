require 'thread'
require 'concurrent/atomic_reference/direct_update'
require 'concurrent/atomic_reference/numeric_cas_wrapper'

module Concurrent

  # @!macro atomic_reference
  class MutexAtomic
    include Concurrent::AtomicDirectUpdate
    include Concurrent::AtomicNumericCompareAndSetWrapper

    # @!macro [attach] atomic_reference_method_initialize
    def initialize(value = nil)
      @mutex = Mutex.new
      @value = value
    end

    # @!macro [attach] atomic_reference_method_get
    #
    #   Gets the current value.
    #
    #   @return [Object] the current value
    def get
      @mutex.synchronize { @value }
    end
    alias_method :value, :get

    # @!macro [attach] atomic_reference_method_set
    #
    #   Sets to the given value.
    #
    #   @param [Object] new_value the new value
    #
    #   @return [Object] the new value
    def set(new_value)
      @mutex.synchronize { @value = new_value }
    end
    alias_method :value=, :set

    # @!macro [attach] atomic_reference_method_get_and_set
    #
    #   Atomically sets to the given value and returns the old value.
    #
    #   @param [Object] new_value the new value
    #
    #   @return [Object] the old value
    def get_and_set(new_value)
      @mutex.synchronize do
        old_value = @value
        @value = new_value
        old_value
      end
    end
    alias_method :swap, :get_and_set

    # @!macro [attach] atomic_reference_method_compare_and_set
    #
    #   Atomically sets the value to the given updated value if
    #   the current value == the expected value.
    #
    #   @param [Object] old_value the expected value
    #   @param [Object] new_value the new value
    #
    #   @return [Boolean] `true` if successful. A `false` return indicates
    #   that the actual value was not equal to the expected value.
    def _compare_and_set(old_value, new_value) #:nodoc:
      return false unless @mutex.try_lock
      begin
        return false unless @value.equal? old_value
        @value = new_value
      ensure
        @mutex.unlock
      end
      true
    end
  end
end
