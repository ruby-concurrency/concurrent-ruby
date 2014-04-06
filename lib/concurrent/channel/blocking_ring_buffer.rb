module Concurrent
  class BlockingRingBuffer

    def initialize(capacity)
      @buffer = Array.new(capacity)
      @first = @last = 0
      @count = 0
      @mutex = Mutex.new
      @condition = Condition.new
    end

    def capacity
      @mutex.synchronize { @buffer.size }
    end

    def count
      @mutex.synchronize { @count }
    end

    def full?
      @mutex.synchronize { @count == @buffer.size }
    end

    def empty?
      @mutex.synchronize { @count == 0 }
    end

    def put(value)
      @mutex.synchronize do
        wait_while_full
        @buffer[@last] = value
        @last = (@last + 1) % @buffer.size
        @count += 1
        @condition.signal
      end
    end

    def take
      @mutex.synchronize do
        wait_while_empty
        result = @buffer[@first]
        @buffer[@first] = nil
        @first = (@first + 1) % @buffer.size
        @count -= 1
        @condition.signal
        result
      end
    end

    def peek
      @mutex.synchronize { @buffer[@first] }
    end

    private

    def wait_while_full
      @condition.wait(@mutex) while @count == @buffer.size
    end

    def wait_while_empty
      @condition.wait(@mutex) while @count == 0
    end

  end
end