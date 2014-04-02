module Concurrent
  class BufferedChannel

    def initialize(size)
      @mutex = Mutex.new
      @condition = Condition.new
      @buffer_condition = Condition.new

      @probe_set = []
      @buffer = []
      @size = size
    end

    def probe_set_size
      @mutex.synchronize { @probe_set.size }
    end

    def buffer_queue_size
      @mutex.synchronize { @buffer.size }
    end

    def push(value)
      until set_probe_or_push_into_buffer(value)
      end
    end

    def pop
      probe = Probe.new
      select(probe)
      probe.value
    end

    def select(probe)
      @mutex.synchronize do

        if @buffer.empty?
          @probe_set << probe
          true
        else
          shift_buffer if probe.set_unless_assigned peek_buffer
        end

      end
    end

    def remove_probe(probe)
      @mutex.synchronize { @probe_set.delete(probe) }
    end

    private

    def buffer_full?
      @buffer.size == @size
    end

    def buffer_empty?
      @buffer.empty?
    end

    def push_into_buffer(value)
      @buffer_condition.wait(@mutex) while buffer_full?
      @buffer << value
      @buffer_condition.broadcast
    end

    def peek_buffer
      @buffer_condition.wait(@mutex) while buffer_empty?
      @buffer.first
    end

    def shift_buffer
      @buffer_condition.wait(@mutex) while buffer_empty?
      result = @buffer.shift
      @buffer_condition.broadcast
      result
    end

    def set_probe_or_push_into_buffer(value)
      @mutex.synchronize do
        if @probe_set.empty?
          push_into_buffer(value)
          true
        else
          @probe_set.shift.set_unless_assigned(value)
        end
      end
    end

  end
end