warn 'unsupported Ruby engine, using less-efficient Atomic impl' if $VERBOSE

require 'thread'
require 'atomic/direct_update'

# Portable/generic (but not very memory or scheduling-efficient) fallback
class Atomic #:nodoc: all
  def initialize(value)
    @mutex = Mutex.new
    @value = value
  end

  def get
    @mutex.synchronize { @value }
  end
  alias value get

  def set(new_value)
    @mutex.synchronize { @value = new_value }
  end
  alias value= set

  def get_and_set(new_value)
    @mutex.synchronize do
      old_value = @value
      @value = new_value
      old_value
    end
  end
  alias swap get_and_set

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
  alias compare_and_swap compare_and_set
end