require 'concurrent/atomic/atomic_fixnum'
require 'concurrent/collection/non_concurrent_priority_queue'
require 'concurrent/synchronization/object'
require 'concurrent/utility/monotonic_time'

module Concurrent

  # @!visibility private
  # @!macro internal_implementation_note
  class RubyPriorityBlockingQueue < Synchronization::Object

    def initialize(opts = {})
      super()
      @queue = Concurrent::Collection::NonConcurrentPriorityQueue.new(opts)
      @waiters = Concurrent::AtomicFixnum.new(0)
      ensure_ivar_visibility!
    end

    def clear
      synchronize { @queue.clear }
      self
    end

    def empty?
      synchronize { @queue.empty? }
    end

    def length
      synchronize { @queue.length }
    end
    alias_method :size, :length

    def num_waiting
      @waiters.value
    end

    def poll(timeout = nil)
      return synchronize { @queue.pop } if timeout.nil?
      pop_with_blocking(Concurrent.monotonic_time + timeout)
    end

    def pop(non_block = false)
      if non_block
        pop_non_blocking
      else
        pop_with_blocking(nil)
      end
    end
    alias_method :deq, :pop
    alias_method :shift, :pop

    def push(obj)
      raise ArgumentError.new('cannot enqueue nil') if obj.nil?
      synchronize { @queue.push(obj) }
    end
    alias_method :<<, :push
    alias_method :enq, :push

    private

    def pop_non_blocking
      item = synchronize { @queue.pop }
      raise ThreadError.new('queue empty') unless item
      item
    end

    def pop_with_blocking(end_at)
      @waiters.increment
      loop do
        item = synchronize { @queue.pop }
        if item
          @waiters.decrement
          break item
        elsif end_at && Concurrent.monotonic_time > end_at
          break nil
        end
      end
    end
  end

  if Concurrent.on_jruby?

    # @!visibility private
    # @!macro internal_implementation_note
    class JavaPriorityBlockingQueue

      def initialize(opts = {})
        order = opts.fetch(:order, :max)
        if [:min, :low].include?(order)
          @queue = java.util.concurrent.PriorityBlockingQueue.new(11) # 11 is the default initial capacity
        else
          @queue = java.util.concurrent.PriorityBlockingQueue.new(11, java.util.Collections.reverseOrder())
        end
        @waiters = Concurrent::AtomicFixnum.new(0)
      end

      def clear
        @queue.clear
        self
      end

      def empty?
        length == 0
      end

      def length
        @queue.size
      end
      alias_method :size, :length

      def num_waiting
        @waiters.value
      end

      def poll(timeout = nil)
        if timeout.nil?
          @queue.poll
        else
          @queue.poll(timeout, java.util.concurrent.TimeUnit::SECONDS)
        end
      end

      def pop(non_block = false)
        if non_block
          item = @queue.poll
          raise ThreadError.new('queue empty') unless item
          item
        else
          @waiters.increment
          item = @queue.take
          @waiters.decrement
          item
        end
      end
      alias_method :deq, :pop
      alias_method :shift, :pop

      def push(obj)
        raise ArgumentError.new('cannot enqueue nil') if obj.nil?
        @queue.add(obj)
      end
      alias_method :<<, :push
      alias_method :enq, :push
    end
  end

  # @!visibility private
  # @!macro internal_implementation_note
  PriorityBlockingQueueImplementation = case
                                        when Concurrent.on_jruby?
                                          JavaPriorityBlockingQueue
                                        else
                                          RubyPriorityBlockingQueue
                                        end
  private_constant :PriorityBlockingQueueImplementation

  # @!macro priority_queue
  # 
  # @!visibility private
  class PriorityBlockingQueue < PriorityBlockingQueueImplementation
  end
end
