module Concurrent
  class Probe < IVar

    def initialize(value = NO_VALUE, opts = {})
      super(value, opts)
    end

    def set_unless_assigned(value)
      mutex.synchronize do
        return false if [:fulfilled, :rejected].include? @state

        set_state(true, value, nil)
        event.set
        true
      end

    end
  end
end