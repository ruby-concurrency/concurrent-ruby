require 'concurrent_needed'
require 'concurrent/synchronization'
require 'concurrent/atomics'

class CRFuture < Concurrent::Synchronization::Object
  PENDING = Object.new

  safe_initialization!

  # also defines reader and writer methods
  private *attr_volatile(:volatile_value)

  def initialize
    super
    @Lock               = Mutex.new
    @Condition          = ConditionVariable.new
    self.volatile_value = PENDING
  end

  def complete?(value = volatile_value)
    value != PENDING
  end

  def value
    # read only once
    value = volatile_value
    return value if complete? value

    # critical section
    @Lock.synchronize do
      until complete?(value = volatile_value)
        # blocks thread until it is broadcasted
        @Condition.wait @Lock
      end
    end

    value
  end

  def fulfill(value)
    @Lock.synchronize do
      raise 'already fulfilled' if complete?
      self.volatile_value = value
      @Condition.broadcast
    end

    self
  end
end
