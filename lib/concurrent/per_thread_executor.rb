module Concurrent

  class PerThreadExecutor

    def self.post(*args)
      Thread.new(*args) do
        Thread.current.abort_on_exception = false
        yield(*args)
      end
      return true
    end

    def post(*args, &block)
      return PerThreadExecutor.post(*args, &block)
    end

    def <<(block)
      PerThreadExecutor.post(&block)
      return self
    end
  end
end
