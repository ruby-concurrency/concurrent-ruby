class Atomic
  class ConcurrentUpdateError < ThreadError
  end
  
  def initialize(value=nil)
    @ref = InternalReference.new(value)
  end

  def value
    @ref.get
  end
  alias get value
  
  def value=(new_value)
    @ref.set(new_value)
    new_value
  end
  alias set value=

  def swap(new_value)
    @ref.get_and_set(new_value)
  end
  alias get_and_set swap
  
  def compare_and_swap(old_value, new_value)
    @ref.compare_and_set(old_value, new_value)
  end
  alias compare_and_set compare_and_swap

  # Pass the current value to the given block, replacing it
  # with the block's result. May retry if the value changes
  # during the block's execution.
  def update
    true until @ref.compare_and_set(old_value = @ref.get, new_value = yield(old_value))
    new_value
  end
  
  # frozen pre-allocated backtrace to speed ConcurrentUpdateError
  CONC_UP_ERR_BACKTRACE = ['backtrace elided; set verbose to enable'].freeze

  def try_update
    old_value = @ref.get
    new_value = yield old_value
    unless @ref.compare_and_set(old_value, new_value)
      if $VERBOSE
        raise ConcurrentUpdateError, "Update failed"
      else
        raise ConcurrentUpdateError, "Update failed", CONC_UP_ERR_BACKTRACE
      end
    end
    new_value
  end
end