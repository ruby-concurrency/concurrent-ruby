module Concurrent
  class ImmediateExecutor

    def post(*args, &block)
      block.call(*args)
    end

    def <<(block)
      post(&block)
      self
    end

  end
end