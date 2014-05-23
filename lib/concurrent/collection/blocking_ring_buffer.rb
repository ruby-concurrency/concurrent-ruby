require 'concurrent/atomic/condition'

module Concurrent
  class BlockingRingBuffer

    def initialize(capacity)
      @buffer = RingBuffer.new(capacity)
      @first = @last = 0
      @count = 0
      @mutex = Mutex.new
      @condition = Condition.new
    end

    # @return [Integer] the capacity of the buffer
    def capacity
      @mutex.synchronize { @buffer.capacity }
    end

    # @return [Integer] the number of elements currently in the buffer
    def count
      @mutex.synchronize { @buffer.count }
    end

    # @return [Boolean] true if buffer is empty, false otherwise
    def empty?
      @mutex.synchronize { @buffer.empty? }
    end

    # @return [Boolean] true if buffer is full, false otherwise
    def full?
      @mutex.synchronize { @buffer.full? }
    end

    # @param [Object] value the value to be inserted
    # @return [Boolean] true if value has been inserted, false otherwise
    def put(value)
      @mutex.synchronize do
        wait_while_full
        @buffer.offer(value)
        @condition.signal
        true
      end
    end

    # @return [Object] the first available value and removes it from the buffer. If buffer is empty it blocks until an element is available
    def take
      @mutex.synchronize do
        wait_while_empty
        result = @buffer.poll
        @condition.signal
        result
      end
    end

    # @return [Object] the first available value and without removing it from the buffer. If buffer is empty returns nil
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
