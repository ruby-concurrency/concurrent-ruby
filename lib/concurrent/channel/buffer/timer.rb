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
          loop do
            result, tick = do_poll
            if result == :closed
              return NO_VALUE
            elsif result == :tick
              return tick
            end
            Thread.pass
          end
        end

        def next
          loop do
            status, tick = do_poll
            if status == :closed
              return NO_VALUE, false
            elsif status == :tick
              return tick, false
              # AFAIK a Go timer will block forever if stopped
              #elsif status == :closed
              #return false, false
            end
            Thread.pass
          end
        end

        def poll
          status, tick = do_poll
          status == :tick ? tick : NO_VALUE
        end

        private

        def ns_initialize(delay)
          @tick = Concurrent.monotonic_time + delay.to_f
          self.capacity = 1
        end

        def ns_size() 0; end

        def ns_empty?() false; end

        def ns_full?() true; end

        def do_poll
          synchronize do
            if ns_closed?
              return :closed, false
            elsif Concurrent.monotonic_time > @tick
              # only one listener gets notified
              self.closed = true
              return :tick, Concurrent::Channel::Tick.new(@tick)
            else
              return :wait, true
            end
          end
        end
      end
    end
  end
end
