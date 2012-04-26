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
  alias get value
  
  def value=(new_value)
    @ref.set(new_value)
    new_value
  end
  alias set value=

  def swap(new_value)
    @ref.get_and_set(new_value)
  end
  alias get_and_set swap
  
  def compare_and_swap(old_value, new_value)
    @ref.compare_and_set(old_value, new_value)
  end
  alias compare_and_set compare_and_swap

  # Pass the current value to the given block, replacing it
  # with the block's result. May retry if the value changes
  # during the block's execution.
  def update
    true until @ref.compare_and_set(old_value = @ref.get, new_value = yield(old_value))
    new_value
  end
  
  # frozen pre-allocated backtrace to speed ConcurrentUpdateError
  CONC_UP_ERR_BACKTRACE = ['backtrace elided; set verbose to enable'].freeze

  def try_update
    old_value = @ref.get
    new_value = yield old_value
    unless @ref.compare_and_set(old_value, new_value)
      if $VERBOSE
        raise ConcurrentUpdateError, "Update failed"
      else
        raise ConcurrentUpdateError, "Update failed", CONC_UP_ERR_BACKTRACE
      end
    end
    new_value
  end
end

begin
  ruby_engine = defined?(RUBY_ENGINE)? RUBY_ENGINE : 'ruby'
  case ruby_engine
  when 'jruby', 'ruby'
    require 'atomic_reference'
  when 'rbx'
    Atomic::InternalReference = Rubinius::AtomicReference
  else
    raise LoadError
  end
rescue LoadError
  warn 'unsupported Ruby engine, using less-efficient Atomic impl' if $VERBOSE
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
end
