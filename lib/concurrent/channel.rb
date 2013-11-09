require 'concurrent/actor'

module Concurrent

  class Channel < Actor

    def initialize(&block)
      raise ArgumentError.new('no block given') unless block_given?
      super()
      @task = block
    end

    private

    def act(*message)
      return @task.call(*message)
    end
  end
end
