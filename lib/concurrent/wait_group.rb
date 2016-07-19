module Concurrent
  class WaitGroup
    def initialize
      @mutex = Mutex.new
      @count = 0
      @waiting = []
    end

    def add(delta)
      sync! do
        @count += delta
        fail 'negative WaitGroup counter' if @count < 0
        if @waiting.any? && delta > 0 && @count == delta
          fail 'misuse: add called concurrently with wait'
        end
        wake!
      end
    end

    def done
      add(-1)
    end

    private def done?
      @count == 0
    end

    def wait
      sync! do
        @waiting << Channel::Runtime.current
        @mutex.sleep until done?
      end
    end

    private def wake!
      @waiting.each { |t| t.wakeup if t.alive? }
    end

    private def sync!(&block)
      @mutex.synchronize(&block)
    end
  end
end
