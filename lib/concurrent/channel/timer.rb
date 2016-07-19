module Concurrent
  class Channel
    class Timer
      attr_reader :channel

      def initialize(delay)
        @stopped = false
        @channel = Channel.new(1)
        @prc = -> { sleep delay; send_time unless @stopped }
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

      def self.after(delay)
        new(delay).channel
      end
    end
  end
end