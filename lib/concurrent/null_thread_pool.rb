require 'concurrent/global_thread_pool'

module Concurrent

  class NullThreadPool

    def self.post(*args)
      Thread.new(*args) do
        Thread.current.abort_on_exception = false
        yield(*args)
      end
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
