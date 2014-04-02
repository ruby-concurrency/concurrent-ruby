module Concurrent
  class UnbufferedChannel

    def initialize
      @mutex = Mutex.new
      @condition = Condition.new

      @probe_set = []
    end

    def probe_set_size
      @mutex.synchronize { @probe_set.size }
    end

    def push(value)
      until first_waiting_probe.set_unless_assigned(value)
      end
    end

    def pop
      probe = Probe.new
      select(probe)
      probe.value
    end

    def select(probe)
      @mutex.synchronize do
        @probe_set << probe
        @condition.signal
      end
    end

    def remove_probe(probe)
      @mutex.synchronize { @probe_set.delete(probe) }
    end

    private
    def first_waiting_probe
      @mutex.synchronize do
        @condition.wait(@mutex) while @probe_set.empty?
        @probe_set.shift
      end
    end

  end
end