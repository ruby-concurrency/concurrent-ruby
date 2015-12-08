require 'java'

class JRubyFuture
  java_import java.util.concurrent.atomic.AtomicReference
  java_import org.jruby.util.unsafe.UnsafeHolder

  PENDING = Object.new

  def initialize
    @Value   = AtomicReference.new PENDING
    UnsafeHolder.fullFence
  end

  def complete?(value = @Value.get)
    value != PENDING
  end

  def value
    # read only once
    value = @Value.get
    return value if complete? value

    JRuby.reference(self).synchronized do
      # recheck is in the loop condition
      until complete?(value = @Value.get)
        # may wakeup spuriously, therefore kept in a loop
        JRuby.reference(self).wait
      end
    end

    value
  end

  def fulfill(value)
    JRuby.reference(self).synchronized do
      raise 'already fulfilled' if complete?
      @Value.set value
      JRuby.reference(self).notify_all
    end

    self
  end
end
