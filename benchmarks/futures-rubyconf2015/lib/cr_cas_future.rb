require 'concurrent_needed'
require 'concurrent/synchronization'
require 'concurrent/atomics'

class CRCasFuture < Concurrent::Synchronization::Object

  class Node < Concurrent::Synchronization::Object
    attr_volatile(:awake)

    safe_initialization!

    def initialize(thread)
      super()
      @Thread    = thread
      self.awake = false
    end

    def thread
      @Thread
    end
  end

  safe_initialization!
  PENDING = Object.new

  attr_atomic(:atomic_value)
  attr_atomic(:head)

  def initialize
    super
    self.head         = nil
    self.atomic_value = PENDING
  end

  def complete?(value = atomic_value)
    value != PENDING
  end

  def value
    value = atomic_value
    return value if complete? value

    begin
      while true
        head = self.head
        node = Node.new Thread.current
        break if compare_and_set_head head, node
      end

      until complete?(value = atomic_value)
        # may go to sleep even if completed, but it has a record by then
        sleep
      end

      value
    ensure
      node.awake = true
      wakeup head
    end
  end

  def fulfill(value)
    if compare_and_set_atomic_value(PENDING, value)
      wakeup head
    else
      raise 'already fulfilled'
    end
    self
  end

  private

  def wakeup(node)
    return unless node

    while true
      break if node.awake
      # has to be confirmed
      node.thread.wakeup
      Thread.pass
    end
  end
end
