class GVLFuture
  PENDING = Object.new

  def initialize
    @lock      = Mutex.new
    @condition = ConditionVariable.new
    @value     = PENDING
  end

  def complete?(value = @value)
    value != PENDING
  end

  def value
    value = @value
    return value if complete? value

    @lock.synchronize do
      # recheck complete?
      @condition.wait @lock unless complete? @value
    end

    @value
  end

  def fulfill(value)
    # why not check complete? before synchronizing?

    @lock.synchronize do
      raise 'already fulfilled' if complete?
      @value = value
      @condition.broadcast
      self
    end
  end
end
