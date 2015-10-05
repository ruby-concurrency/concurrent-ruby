require 'concurrent/utility/monotonic_time'
require 'concurrent/channel/tick'
require 'concurrent/channel/buffer/base'

module Concurrent
  class Channel
    module Buffer

      class Ticker < Base

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

        def ns_initialize(interval)
          @interval = interval.to_f
          @next_tick = Concurrent.monotonic_time + interval
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
            if !ns_closed? && (now = Concurrent.monotonic_time) >= @next_tick
              tick = Concurrent::Channel::Tick.new(@next_tick)
              @next_tick = now + @interval
              return tick
            else
              return NO_VALUE
            end
          end
        end
      end
    end
  end
end
