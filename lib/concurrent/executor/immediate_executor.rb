module Concurrent
  class ImmediateExecutor

    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      task.call(*args)
      true
    end

    def <<(task)
      post(&task)
      self
    end
  end
end
