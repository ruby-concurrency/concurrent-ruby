module Concurrent
  class UnbufferedChannel

    def initialize
      @mutex = Mutex.new
      @condition = Condition.new

      @wait_set = []
    end

    def push(value)
      probe = @mutex.synchronize do
        @condition.wait(@mutex) while @wait_set.empty?
        @wait_set.shift
      end

      probe.set(value)
    end

    def pop
      probe = IVar.new

      @mutex.synchronize do
        @wait_set << probe
        @condition.signal
      end

      probe.value
    end

    def select(probe)
    end

    def remove_probe(probe)
    end

  end
end