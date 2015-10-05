require 'concurrent/utility/monotonic_time'
require 'concurrent/channel/tick'
require 'concurrent/channel/buffer/base'

module Concurrent
  class Channel
    module Buffer

      class Timer < Base

        def put(item)
          false
        end

        def offer(item)
          false
        end

        def take
          # a Go timer will block forever if stopped
          loop do
            tick = do_poll
            return tick if tick != NO_VALUE
            Thread.pass
          end
        end

        def next
          # a Go timer will block forever if stopped
          # it will always return `true` for more
          loop do
            tick = do_poll
            return tick, true if tick != NO_VALUE
            Thread.pass
          end
        end

        def poll
          do_poll
        end

        private

        def ns_initialize(delay)
          @tick = Concurrent.monotonic_time + delay.to_f
          self.capacity = 1
        end

        def ns_size
          0
        end

        def ns_empty?
          false
        end

        def ns_full?
          true
        end

        def do_poll
          synchronize do
            if !ns_closed? && Concurrent.monotonic_time >= @tick
              # only one listener gets notified
              self.closed = true
              return Concurrent::Channel::Tick.new(@tick)
            else
              return NO_VALUE
            end
          end
        end
      end
    end
  end
end
