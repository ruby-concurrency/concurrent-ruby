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
  #       Concurrent::Future.new { n }
  #     else
  #       n1 = fib(n - 1).execute
  #       n2 = fib(n - 2).execute
  #       Concurrent::Future.new { n1.value + n2.value }
  #     end
  #   end
  #   
  #   f = fib(14) #=> #<Concurrent::Future:0x000001019ef5a0 ...
  #   f.execute   #=> #<Concurrent::Future:0x000001019ef5a0 ...
  #   
  #   sleep(0.5)
  #   
  #   f.value #=> 377
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
