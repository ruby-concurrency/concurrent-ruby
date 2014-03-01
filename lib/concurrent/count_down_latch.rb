module Concurrent
  class CountDownLatch

    def initialize(count)
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @count = count
    end

    def wait(timeout = nil)
      @mutex.synchronize do
        @condition.wait(@mutex, timeout) if @count > 0
        @count == 0
      end
    end

    def count_down
      @mutex.synchronize do
        @count -= 1 if @count > 0
        @condition.broadcast if @count == 0
      end
    end

    def count
      @mutex.synchronize { @count }
    end

  end
end