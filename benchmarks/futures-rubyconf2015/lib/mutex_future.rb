require 'thread'

class MutexFuture
  PENDING = Object.new

  def initialize
    # non-re-entrant lock
    @lock      = Mutex.new
    # allows to block treads until the condition is met
    @condition = ConditionVariable.new
    @value     = PENDING
  end

  def complete?(value = @lock.synchronize { @value })
    value != PENDING
  end

  def value
    # critical section, visibility
    @lock.synchronize do
      return @value if complete? @value

      @condition.wait @lock
      @value
    end
  end

  def fulfill(value)
    @lock.synchronize do
      raise 'already fulfilled' if complete? @value

      @value = value
      @condition.broadcast
    end
    self
  end
end
