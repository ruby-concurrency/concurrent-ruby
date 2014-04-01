require 'concurrent/atomic'
require 'concurrent/future'
require 'concurrent/per_thread_executor'

module Concurrent

  # @!visibility private
  class DependencyCounter # :nodoc:

    def initialize(count, &block)
      @counter = AtomicFixnum.new(count)
      @block = block
    end

    def update(time, value, reason)
      if @counter.decrement == 0
        @block.call
      end
    end
  end

  # Dataflow allows you to create a task that will be scheduled then all of its
  # data dependencies are available. Data dependencies are +Future+ values. The
  # dataflow task itself is also a +Future+ value, so you can build up a graph of
  # these tasks, each of which is run when all the data and other tasks it depends
  # on are available or completed.
  #
  # Our syntax is somewhat related to that of Akka's +flow+ and Habanero Java's
  # +DataDrivenFuture+. However unlike Akka we don't schedule a task at all until
  # it is ready to run, and unlike Habanero Java we pass the data values into the
  # task instead of dereferencing them again in the task.
  #
  # The theory of dataflow goes back to the 80s. In the terminology of the literature,
  # our implementation is coarse-grained, in that each task can be many instructions,
  # and dynamic in that you can create more tasks within other tasks.
  #
  # @example Parallel Fibonacci calculator
  #   def fib(n)
  #     if n < 2
  #       Concurrent::dataflow { n }
  #     else
  #       n1 = fib(n - 1)
  #       n2 = fib(n - 2)
  #       Concurrent::dataflow(n1, n2) { |v1, v2| v1 + v2 }
  #     end
  #   end
  #   
  #   f = fib(14) #=> #<Concurrent::Future:0x000001019a26d8 ...
  #   
  #   # wait up to 1 second for the answer...
  #   f.value(1) #=> 377
  #
  # @param [Future] inputs zero or more +Future+ operations that this dataflow depends upon
  #
  # @yield The operation to perform once all the dependencies are met
  # @yieldparam [Future] inputs each of the +Future+ inputs to the dataflow
  # @yieldreturn [Object] the result of the block operation
  #
  # @return [Object] the result of all the operations
  #
  # @raise [ArgumentError] if no block is given
  # @raise [ArgumentError] if any of the inputs are not +IVar+s
  def dataflow(*inputs, &block)
    raise ArgumentError.new('no block given') unless block_given?
    raise ArgumentError.new('not all dependencies are IVars') unless inputs.all? { |input| input.is_a? IVar }

    result = Future.new(executor: PerThreadExecutor.new) do
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
