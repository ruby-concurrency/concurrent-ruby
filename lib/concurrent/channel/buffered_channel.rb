require 'concurrent/synchronization'
require 'concurrent/channel/waitable_list'

module Concurrent
  module Channel

    # @api Channel
    # @!macro edge_warning
    class BufferedChannel < Synchronization::LockableObject

      def initialize(size)
        super()
        synchronize { ns_initialize(size) }
      end

      def probe_set_size
        @probe_set.size # TODO (pitr 12-Sep-2015): unsafe?
      end

      def buffer_queue_size
        synchronize { @buffer.count }
      end

      def push(value)
        until set_probe_or_ns_push_into_buffer(value)
        end
      end

      def pop
        probe = Channel::Probe.new
        select(probe)
        probe.value
      end

      def select(probe)
        synchronize do
          if @buffer.empty?
            @probe_set.put(probe)
            true
          else
            ns_shift_buffer if probe.try_set([ns_peek_buffer, self])
          end
        end
      end

      def remove_probe(probe)
        @probe_set.delete(probe)
      end

      protected

      def ns_initialize(size)
        @probe_set = WaitableList.new
        @buffer = RingBuffer.new(size)
      end

      private

      def ns_push_into_buffer(value)
        ns_wait while @buffer.full?
        @buffer.offer value
        ns_broadcast
      end

      def ns_peek_buffer
        ns_wait while @buffer.empty?
        @buffer.peek
      end

      def ns_shift_buffer
        ns_wait while @buffer.empty?
        result = @buffer.poll
        ns_broadcast
        result
      end

      def set_probe_or_ns_push_into_buffer(value)
        synchronize do
          if @probe_set.empty?
            ns_push_into_buffer(value)
            true
          else
            @probe_set.take.try_set([value, self])
          end
        end
      end
    end
  end
end
