module Concurrent

  class PerThreadExecutor
    include Executor

    def self.post(*args)
      raise ArgumentError.new('no block given') unless block_given?
      Thread.new(*args) do
        Thread.current.abort_on_exception = false
        yield(*args)
      end
      return true
    end

    def post(*args, &task)
      return PerThreadExecutor.post(*args, &task)
    end

    def <<(task)
      PerThreadExecutor.post(&task)
      return self
    end
  end
end
