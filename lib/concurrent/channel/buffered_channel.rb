require 'concurrent/atomic/condition'

require_relative 'waitable_list'

module Concurrent
  class BufferedChannel

    def initialize(size)
      @mutex = Mutex.new
      @condition = Condition.new
      @buffer_condition = Condition.new

      @probe_set = WaitableList.new
      @buffer = RingBuffer.new(size)
    end

    def probe_set_size
      @probe_set.size
    end

    def buffer_queue_size
      @mutex.synchronize { @buffer.count }
    end

    def push(value)
      until set_probe_or_push_into_buffer(value)
      end
    end

    def pop
      probe = Channel::Probe.new
      select(probe)
      probe.value
    end

    def select(probe)
      @mutex.synchronize do

        if @buffer.empty?
          @probe_set.put(probe)
          true
        else
          shift_buffer if probe.set_unless_assigned(peek_buffer, self)
        end

      end
    end

    def remove_probe(probe)
      @probe_set.delete(probe)
    end

    private

    def push_into_buffer(value)
      @buffer_condition.wait(@mutex) while @buffer.full?
      @buffer.offer value
      @buffer_condition.broadcast
    end

    def peek_buffer
      @buffer_condition.wait(@mutex) while @buffer.empty?
      @buffer.peek
    end

    def shift_buffer
      @buffer_condition.wait(@mutex) while @buffer.empty?
      result = @buffer.poll
      @buffer_condition.broadcast
      result
    end

    def set_probe_or_push_into_buffer(value)
      @mutex.synchronize do
        if @probe_set.empty?
          push_into_buffer(value)
          true
        else
          @probe_set.take.set_unless_assigned(value, self)
        end
      end
    end

  end
end
