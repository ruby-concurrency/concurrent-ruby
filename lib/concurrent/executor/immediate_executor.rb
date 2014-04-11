module Concurrent
  class ImmediateExecutor

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      block.call(*args)
      return true
    end

    def <<(block)
      post(&block)
      self
    end
  end
end
