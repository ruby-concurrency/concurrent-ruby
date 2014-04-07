module Concurrent
  class BlockingRingBuffer

    def initialize(capacity)
      @buffer = RingBuffer.new(capacity)
      @first = @last = 0
      @count = 0
      @mutex = Mutex.new
      @condition = Condition.new
    end

    def capacity
      @mutex.synchronize { @buffer.capacity }
    end

    def count
      @mutex.synchronize { @buffer.count }
    end

    def full?
      @mutex.synchronize { @buffer.full? }
    end

    def empty?
      @mutex.synchronize { @buffer.empty? }
    end

    def put(value)
      @mutex.synchronize do
        wait_while_full
        @buffer.offer(value)
        @condition.signal
      end
    end

    def take
      @mutex.synchronize do
        wait_while_empty
        result = @buffer.poll
        @condition.signal
        result
      end
    end

    def peek
      @mutex.synchronize { @buffer.peek }
    end

    private

    def wait_while_full
      @condition.wait(@mutex) while @buffer.full?
    end

    def wait_while_empty
      @condition.wait(@mutex) while @buffer.empty?
    end

  end
end