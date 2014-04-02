module Concurrent
  class UnbufferedChannel

    def initialize
      @mutex = Mutex.new
      @condition = Condition.new

      @wait_set = []
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
        @wait_set << probe
        @condition.signal
      end
    end

    def remove_probe(probe)
    end

    private
      def first_waiting_probe
        @mutex.synchronize do
          @condition.wait(@mutex) while @wait_set.empty?
          @wait_set.shift
        end
      end

  end
end