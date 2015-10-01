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
          loop do
            result, _ = do_poll
            if result.nil?
              return NO_VALUE
            elsif result != NO_VALUE
              return result
            end
          end
        end

        def next
          loop do
            result, _ = do_poll
            if result.nil?
              return NO_VALUE, false
            elsif result != NO_VALUE
              return result, true
            end
          end
        end

        def poll
          result, _ = do_poll
          if result.nil? || result == NO_VALUE
            NO_VALUE
          else
            result
          end
        end

        private

        def ns_initialize(interval)
          @interval = interval.to_f
          @next_tick = Concurrent.monotonic_time + interval
          self.capacity = 1
        end

        def ns_size() 0; end

        def ns_empty?() false; end

        def ns_full?() true; end

        def do_poll
          if ns_closed?
            return nil, false
          elsif (now = Concurrent.monotonic_time) > @next_tick
            tick = Concurrent::Channel::Tick.new(@next_tick)
            @next_tick = now + @interval
            return tick, true
          else
            return NO_VALUE, true
          end
        end
      end
    end
  end
end
