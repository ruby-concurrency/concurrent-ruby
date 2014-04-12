require_relative 'executor'

module Concurrent
  class ImmediateExecutor
    include Executor

    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      task.call(*args)
      return true
    end
  end
end
