module Concurrent
  class WaitableList

    def initialize
      @mutex = Mutex.new
      @condition = Condition.new

      @list = []
    end

    def size
      @mutex.synchronize { @list.size }
    end

    def empty?
      @mutex.synchronize { @list.empty? }
    end

    def push(value)
      @mutex.synchronize do
        @list << value
        @condition.signal
      end
    end

    def delete(value)
      @mutex.synchronize { @list.delete(value) }
    end

    def first
      @mutex.synchronize do
        @condition.wait(@mutex) while @list.empty?
        @list.shift
      end
    end

  end
end