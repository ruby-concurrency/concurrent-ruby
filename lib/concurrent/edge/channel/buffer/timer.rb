require 'concurrent/utility/monotonic_time'
require 'concurrent/edge/channel/tick'
require 'concurrent/edge/channel/buffer/base'

module Concurrent
  module Edge
    class Channel
      module Buffer

        class Timer < Base

          def initialize(delay)
            super()
            synchronize do
              @tick = Concurrent.monotonic_time + delay.to_f
              @closed = false
              @empty = false
            end
          end

          def size() 1; end

          def empty?
            synchronized { @empty }
          end

          def full?
            !empty?
          end

          def put(item)
            false
          end

          def offer(item)
            false
          end

          def take
            self.next.first
          end

          def next
            loop do
              status, tick = do_poll
              if status == :tick
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

          def do_poll
            synchronize do
              return :closed, false if ns_closed?

              if Concurrent.monotonic_time > @tick
                # only one listener gets notified
                @closed = @empty = true
                return :tick, Concurrent::Edge::Channel::Tick.new(@tick)
              else
                return :wait, true
              end
            end
          end
        end
      end
    end
  end
end
