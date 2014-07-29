require_relative 'waitable_list'

module Concurrent
  class UnbufferedChannel

    def initialize
      @probe_set = WaitableList.new
    end

    def probe_set_size
      @probe_set.size
    end

    def push(value)
      # TODO set_unless_assigned define on IVar as #set_state? or #try_set_state
      until @probe_set.take.set_unless_assigned(value, self)
      end
    end

    def pop
      probe = Channel::Probe.new
      select(probe)
      probe.value
    end

    def select(probe)
      @probe_set.put(probe)
    end

    def remove_probe(probe)
      @probe_set.delete(probe)
    end

  end
end
