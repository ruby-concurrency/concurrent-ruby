module Concurrent
  module Channel

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

    def self.select(*channels)
      probe = Probe.new
      channels.each { |channel| channel.select(probe) }
      result = probe.value
      channels.each { |channel| channel.remove_probe(probe) }
      result
    end
  end
end