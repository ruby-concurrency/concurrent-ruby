require 'thread'

class Atomic
  class ConcurrentUpdateError < ThreadError
  end
  
  def initialize(value=nil)
    @ref = InternalReference.new(value)
  end

  def value
    @ref.get
  end
  
  def value=(new_value)
    @ref.set(new_value)
    new_value
  end

  def swap(new_value)
    @ref.get_and_set(new_value)
  end

  # Pass the current value to the given block, replacing it
  # with the block's result. May retry if the value changes
  # during the block's execution.
  def update
    begin
      try_update { |v| yield v }
    rescue ConcurrentUpdateError
      retry
    end
  end

  def try_update
    old_value = @ref.get
    new_value = yield old_value
    unless @ref.compare_and_set(old_value, new_value)
      raise ConcurrentUpdateError, "Update failed"
    end
    new_value
  end
end

begin
  require 'atomic_reference'
rescue LoadError
  # Portable/generic (but not very memory or scheduling-efficient) fallback
  class Atomic::InternalReference
    def initialize(value)
      @mutex = Mutex.new
      @value = value
    end

    def get
      @mutex.synchronize { @value }
    end

    def set(new_value)
      @mutex.synchronize { @value = new_value }
    end

    def get_and_set(new_value)
      @mutex.synchronize do
        old_value = @value
        @value = new_value
        old_value
      end
    end

    def compare_and_set(old_value, new_value)
      @mutex.synchronize do
        return false unless @value.equal? old_value
        @value = new_value
      end
      true
    end
  end
end
