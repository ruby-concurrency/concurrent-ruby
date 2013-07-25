require 'functional/behavior'
require 'concurrent/event'

behavior_info(:thread_pool,
              running?: 0,
              shutdown?: 0,
              killed?: 0,
              shutdown: 0,
              kill: 0,
              size: 0,
              wait_for_termination: -1,
              post: -1,
              :<< => 1,
              status: 0)

behavior_info(:global_thread_pool,
              post: -1,
              :<< => 1)

module Concurrent

  class ThreadPool

    def initialize
      @status = :running
      @queue = Queue.new
      @termination = Event.new
      @pool = []
    end

    def running?
      return @status == :running
    end

    def shutdown?
      return ! running?
    end

    def killed?
      return @status == :killed
    end

    def shutdown
      @pool.size.times{ @queue << :stop }
      @status = :shuttingdown
    end

    def wait_for_termination(timeout = nil)
      if shutdown? || killed?
        return true
      else
        return @termination.wait(timeout)
      end
    end

    def <<(block)
      self.post(&block)
      return self
    end
  end
end
