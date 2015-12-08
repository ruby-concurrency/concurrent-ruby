require 'thread'

class RBXFuture
  PENDING = Object.new

  def initialize
    @Lock      = Mutex.new
    @Condition = ConditionVariable.new
    # reference to a value with volatile semantics
    @Value     = Rubinius::AtomicReference.new PENDING

    # protect against reordering
    Rubinius.memory_barrier
  end

  def complete?(value = @Value.get)
    value != PENDING
  end

  def value
    # read only once
    value = @Value.get
    # check without synchronization
    return value if complete? value

    # critical section
    @Lock.synchronize do
      until complete?(value = @Value.get)
        # blocks thread until it is broadcasted
        @Condition.wait @Lock
      end
    end

    value
  end

  def fulfill(value)
    @Lock.synchronize do
      raise 'already fulfilled' if complete?
      @Value.set value
      @Condition.broadcast
    end

    self
  end
end
