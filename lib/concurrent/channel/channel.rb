require 'concurrent/ivar'

module Concurrent
  module Channel

    class Probe < Concurrent::IVar

      def initialize(value = NO_VALUE, opts = {})
        super(value, opts)
      end

      def set_unless_assigned(value, channel)
        mutex.synchronize do
          return false if [:fulfilled, :rejected].include? @state

          set_state(true, [value, channel], nil)
          event.set
          true
        end
      end

      alias_method :composite_value, :value

      def value
        composite_value.nil? ? nil : composite_value[0]
      end

      def channel
        composite_value.nil? ? nil : composite_value[1]
      end
    end

    def self.select(*channels)
      probe = Probe.new
      channels.each { |channel| channel.select(probe) }
      result = probe.composite_value
      channels.each { |channel| channel.remove_probe(probe) }
      result
    end
  end
end
