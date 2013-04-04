warn 'unsupported Ruby engine, using less-efficient Atomic impl' if $VERBOSE

require 'atomic/shared'
require 'thread'

# Portable/generic (but not very memory or scheduling-efficient) fallback
class Atomic::InternalReference #:nodoc: all
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
    return false unless @mutex.try_lock
    begin
      return false unless @value.equal? old_value
      @value = new_value
    ensure
      @mutex.unlock
    end
    true
  end
end