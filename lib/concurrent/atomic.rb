module Concurrent

  module MutexAtomicFixnum

    def allocate_storage(init)
      @value = init
      @mutex = Mutex.new
    end

    def value
      @mutex.synchronize do
        @value
      end
    end

    def value=(value)
      @mutex.synchronize do
        @value = value
      end
    end

    def increment
      @mutex.synchronize do
        @value += 1
      end
    end

    def decrement
      @mutex.synchronize do
        @value -= 1
      end
    end

    def compare_and_set(expect, update)
      @mutex.synchronize do
        if @value == expect
          @value = update
          true
        else
          false
        end
      end
    end

  end

  module JavaAtomicFixnum

    def allocate_storage(init)
      @atomic = java.util.concurrent.atomic.AtomicLong.new(init)
    end

    def value
      @atomic.get
    end

    def value=(value)
      @atomic.set(value)
    end

    def increment
      @atomic.increment_and_get
    end

    def decrement
      @atomic.decrement_and_get
    end

    def compare_and_set(expect, update)
      @atomic.compare_and_set(expect, update)
    end

  end

  class AtomicFixnum

    def initialize(init = 0)
      raise ArgumentError.new('initial value must be an Fixnum') unless init.is_a?(Fixnum)
      allocate_storage(init)
    end

    if defined? java.util
      include JavaAtomicFixnum
    else
      include MutexAtomicFixnum
    end

    alias_method :up, :increment
    alias_method :down, :decrement

  end
end
