require 'thread'
require 'concurrent/utilities'

module Concurrent

  class Event

    def initialize
      @set = false
      @notifier = Queue.new
      @mutex = Mutex.new
      @waiting = 0
    end

    def set?
      return @set == true
    end

    def set
      return true if set?
      @mutex.synchronize do
        @set = true
        @waiting.times { @notifier << :set }
        @waiting = 0
      end
      return true
    end

    def reset
      @mutex.synchronize { @set = false }
      return true
    end

    def wait(timeout = nil)
      return true if set?

      @mutex.synchronize { @waiting += 1 }

      if timeout.nil?
        @notifier.pop
      else
        Concurrent::timeout(timeout) do
          @notifier.pop
        end
      end
      return true
    rescue
      @mutex.synchronize { @waiting -= 1 }
      return false
    end
  end
end
