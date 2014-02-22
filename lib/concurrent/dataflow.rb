require 'concurrent/future'

module Concurrent

  class CountingObserver

    def initialize(count, &block)
      @count = count
      @block = block
    end

    def update(time, value, reason)
      @count -= 1

      if @count <= 0
        @block.call()
      end
    end

  end

  def dataflow(*inputs, &block)
    result = Concurrent::Future.new(&block)

    if inputs.empty?
      result.execute
    else
      barrier = Concurrent::CountingObserver.new(inputs.size) { result.execute }

      inputs.each do |input|
        input.add_observer barrier
      end
    end

    result
  end

  module_function :dataflow

end
