require 'thread'
require 'concurrent/utilities'

module Concurrent

  class Event

    def initialize
      @set = false
      @mutex = Mutex.new
      @waiters = []
    end

    def set?
      return @set == true
    end

    def set
      return true if set?
      @mutex.synchronize do
        @set = true
        @waiters.each {|waiter| waiter.run if waiter.status == 'sleep'}
      end
      return true
    end

    def reset
      @mutex.synchronize { @set = false; @waiters.clear }
      return true
    end

    def wait(timeout = nil)
      return true if set?

      @mutex.synchronize { @waiters << Thread.current }
      return true if set? # if event was set while waiting for mutex

      if timeout.nil?
        slept = sleep
      else
        slept = sleep(timeout)
      end
    rescue
      # let it fail
    ensure
      @mutex.synchronize { @waiters.delete(Thread.current) }
      return set?
    end
  end
end
