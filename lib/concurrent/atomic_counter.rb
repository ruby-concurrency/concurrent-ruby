module Concurrent

  class AtomicCounter

    def initialize(init = 0)
      raise ArgumentError.new('initial value must be an integer') unless init.is_a?(Integer)
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
    alias_method :up, :increment

    def decrement
      @mutex.synchronize do
        @counter -= 1
      end
    end
    alias_method :down, :decrement
  end
end
