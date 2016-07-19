module Concurrent
  class Channel
    class Ticker
      attr_reader :channel

      def initialize(delay)
        @stopped = false
        @channel = Channel.new(1)
        @prc = lambda do
          # TODO: incorrect, period will drift
          loop { sleep delay; @stopped ? break : send_time }
        end
        start
      end

      def start
        Channel::Runtime.go @prc
      end

      # TODO: incorrect, should return false if stop was a noop
      def stop
        @stopped = true
      end

      private def send_time
        # TODO: use non-blocking select to "drop on the floor"
        channel << Time.now
      end

      def self.tick(period)
        new(period).channel
      end
    end
  end
end