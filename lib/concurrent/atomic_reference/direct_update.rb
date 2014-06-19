require 'concurrent/atomic_reference/concurrent_update_error'

module Concurrent

  # Define update methods that use direct paths
  module AtomicDirectUpdate

    # @!macro [attach] atomic_reference_method_update
    #
    # Pass the current value to the given block, replacing it
    # with the block's result. May retry if the value changes
    # during the block's execution.
    # 
    # @yield [Object] Calculate a new value for the atomic reference using
    #   given (old) value
    # @yieldparam [Object] old_value the starting value of the atomic reference
    #
    # @return [Object] the new value
    def update
      true until compare_and_set(old_value = get, new_value = yield(old_value))
      new_value
    end

    # @!macro [attach] atomic_reference_method_try_update
    #
    # Pass the current value to the given block, replacing it
    # with the block's result. Raise an exception if the update
    # fails.
    # 
    # @yield [Object] Calculate a new value for the atomic reference using
    #   given (old) value
    # @yieldparam [Object] old_value the starting value of the atomic reference
    #
    # @return [Object] the new value
    #
    # @raise [Concurrent::ConcurrentUpdateError] if the update fails
    def try_update
      old_value = get
      new_value = yield old_value
      unless compare_and_set(old_value, new_value)
        if $VERBOSE
          raise ConcurrentUpdateError, "Update failed"
        else
          raise ConcurrentUpdateError, "Update failed", ConcurrentUpdateError::CONC_UP_ERR_BACKTRACE
        end
      end
      new_value
    end
  end
end
