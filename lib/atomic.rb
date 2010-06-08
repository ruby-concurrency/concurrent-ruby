


base_atomic = Class.new do
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
    old_value
  end
end


if MRI
  Atomic = Class.new(base_atomic) do
    class InternalReference
      attr_accessor :value
      alias_method :get, :value
      alias_method :set, :value=

      def initialize(value)
        @value = value
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
elsif JRuby
  Atomic = Class.new(base_atomic) do
    InternalReference = java.util.concurrent.atomic.AtomicReference
  end
end