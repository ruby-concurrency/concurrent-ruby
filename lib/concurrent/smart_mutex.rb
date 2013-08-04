require 'thread'
require 'concurrent/utilities'

module Concurrent

  class SmartMutex

    def initialize
      @mutex = Mutex.new
    end

    def alone?
      Thread.list.length <= 1
    end

    def lock
      atomic do
        @mutex.lock unless alone?
        self
      end
    end

    def locked?
      atomic do
        if alone?
          false
        else
          @mutex.locked?
        end
      end
    end

    def sleep(timeout)
      if alone?
        Kernel.sleep(timeout)
      else
        @mutex.sleep(timeout)
      end
    end

    def synchronize(&block)
      if alone?
        yield
      else
        @mutex.synchronize(&block)
      end
    end

    def try_lock
      atomic do
        if alone?
          true
        else
          @mutex.try_lock
        end
      end
    end

    def unlock
      atomic do
        @mutex.unlock unless alone?
        self
      end
    end
  end
end
