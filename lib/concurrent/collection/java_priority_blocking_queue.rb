if Concurrent.on_jruby?

  module Concurrent

    # @!visibility private
    # @!macro internal_implementation_note
    class JavaPriorityBlockingQueue

      # @!macro priority_blocking_queue_method_initialize
      def initialize(opts = {})
        order = opts.fetch(:order, :max)
        if [:min, :low].include?(order)
          @queue = java.util.concurrent.PriorityBlockingQueue.new(11) # 11 is the default initial capacity
        else
          @queue = java.util.concurrent.PriorityBlockingQueue.new(11, java.util.Collections.reverseOrder())
        end
        @waiters = Concurrent::AtomicFixnum.new(0)
      end

      # @!macro priority_blocking_queue_method_clear
      def clear
        @queue.clear
        self
      end

      # @!macro priority_blocking_queue_method_empty_question
      def empty?
        length == 0
      end

      # @!macro priority_blocking_queue_method_length
      def length
        @queue.size
      end
      alias_method :size, :length

      # @!macro priority_blocking_queue_method_num_waiting
      def num_waiting
        @waiters.value
      end

      # @!macro priority_blocking_queue_method_poll
      def poll(timeout = nil)
        if timeout.nil?
          @queue.poll
        else
          @queue.poll(timeout, java.util.concurrent.TimeUnit::SECONDS)
        end
      end

      # @!macro priority_blocking_queue_method_pop
      def pop(non_block = false)
        non_block ? pop_non_blocking : pop_with_blocking
      end
      alias_method :deq, :pop
      alias_method :shift, :pop

      # @!macro priority_blocking_queue_method_push
      def push(obj)
        raise ArgumentError.new('cannot enqueue nil') if obj.nil?
        @queue.add(obj)
        self
      end
      alias_method :<<, :push
      alias_method :enq, :push

      private

      # @!visibility private
      def pop_non_blocking
        item = @queue.poll
        raise ThreadError.new('queue empty') unless item
        item
      end

      # @!visibility private
      def pop_with_blocking
        @waiters.increment
        item = @queue.take
        @waiters.decrement
        item
      end
    end
  end
end
