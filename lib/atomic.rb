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

if defined? RUBY_ENGINE && RUBY_ENGINE == "jruby"
  require 'atomic_reference'
else
  class Atomic::InternalReference
    attr_accessor :value
    alias_method :get, :value
    alias_method :set, :value=

    def initialize(value)
      @value = value
    end

    def get_and_set(new_value)
      Thread.exclusive do
        old_value = @value
        @value = new_value
        old_value
      end
    end

    def compare_and_set(old_value, new_value)
      Thread.exclusive do 
        return false unless @value.equal? old_value
        @value = new_value
      end
      true
    end
  end
end
