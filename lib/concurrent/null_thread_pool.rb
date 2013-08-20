require 'concurrent/global_thread_pool'

module Concurrent

  class NullThreadPool
    behavior(:global_thread_pool)

    def self.post(*args, &block)
      Thread.new(*args, &block).abort_on_exception = false
      return true
    end

    def post(*args, &block)
      return NullThreadPool.post(*args, &block)
    end

    def <<(block)
      NullThreadPool.post(&block)
      return self
    end
  end
end
