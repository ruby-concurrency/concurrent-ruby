require 'concurrent/atomic'
require 'concurrent/future'

module Concurrent

  # @!visibility private
  class DependencyCounter # :nodoc:

    def initialize(count, &block)
      @counter = AtomicFixnum.new(count)
      @block = block
    end

    def update(time, value, reason)
      if @counter.decrement == 0
        @block.call()
      end
    end
  end

  def dataflow(*inputs, &block)
    raise ArgumentError.new('no block given') unless block_given?
    raise ArgumentError.new('not all dependencies are Futures') unless inputs.all? { |input| input.is_a? Future }

    result = Future.new do
      values = inputs.map { |input| input.value }
      block.call(*values)
    end

    if inputs.empty?
      result.execute
    else
      counter = DependencyCounter.new(inputs.size) { result.execute }

      inputs.each do |input|
        input.add_observer counter
      end
    end

    result
  end

  module_function :dataflow
end
