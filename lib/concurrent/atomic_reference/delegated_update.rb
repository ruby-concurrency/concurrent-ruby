require 'concurrent/atomic_reference/concurrent_update_error'

module Concurrent

  # Define update methods that delegate to @ref field
  class Atomic
    # Pass the current value to the given block, replacing it
    # with the block's result. May retry if the value changes
    # during the block's execution.
    def update
      true until @ref.compare_and_set(old_value = @ref.get, new_value = yield(old_value))
      new_value
    end

    def try_update
      old_value = @ref.get
      new_value = yield old_value
      unless @ref.compare_and_set(old_value, new_value)
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
