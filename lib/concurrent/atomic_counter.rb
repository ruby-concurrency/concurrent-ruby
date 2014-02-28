module Concurrent

  module MutexAtomicCounter

    def allocate_storage
      @counter = init
      @mutex = Mutex.new
    end

    def value
      @mutex.synchronize do
        @counter
      end
    end

    def increment
      @mutex.synchronize do
        @counter += 1
      end
    end

    def decrement
      @mutex.synchronize do
        @counter -= 1
      end
    end

  end

  module JavaAtomicCounter

    def allocate_storage(init)
      @atomic = java.utli.concurrent.atomic.AtomicLong.new(init)
    end

    def value
      @atomic.get
    end

    def increment
      @atomic.incrementAndGet
    end

    def decrement
      @atomic.decrementAndGet
    end

  end

  class AtomicCounter

    def initialize(init = 0)
      raise ArgumentError.new('initial value must be an integer') unless init.is_a?(Integer)
      allocate_storage(init)
    end

    if defined? java.utli.concurrent.atomic.AtomicLong.new
      include ThreadLocalJavaStorage
    else
      include MutexAtomicCounter
    end

    alias_method :up, :increment
    alias_method :down, :decrement

  end
end
