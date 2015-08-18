require 'concurrent/atomic/atomic_fixnum'
require 'concurrent/collection/non_concurrent_priority_queue'
require 'concurrent/synchronization/object'
require 'concurrent/utility/monotonic_time'

module Concurrent

  # @!visibility private
  # @!macro internal_implementation_note
  class MutexPriorityBlockingQueue < Synchronization::Object

    # @!macro priority_blocking_queue_method_initialize
    def initialize(opts = {})
      super()
      @queue = Concurrent::Collection::NonConcurrentPriorityQueue.new(opts)
      @waiters = Concurrent::AtomicFixnum.new(0)
      ensure_ivar_visibility!
    end

    # @!macro priority_blocking_queue_method_clear
    def clear
      synchronize { @queue.clear }
      self
    end

    # @!macro priority_blocking_queue_method_empty_question
    def empty?
      synchronize { @queue.empty? }
    end

    # @!macro priority_blocking_queue_method_length
    def length
      synchronize { @queue.length }
    end
    alias_method :size, :length

    # @!macro priority_blocking_queue_method_num_waiting
    def num_waiting
      @waiters.value
    end

    # @!macro priority_blocking_queue_method_poll
    def poll(timeout = nil)
      return synchronize { @queue.pop } if timeout.nil?
      pop_with_blocking(Concurrent.monotonic_time + timeout)
    end

    # @!macro priority_blocking_queue_method_pop
    def pop(non_block = false)
      non_block ? pop_non_blocking : pop_with_blocking(nil)
    end
    alias_method :deq, :pop
    alias_method :shift, :pop

    # @!macro priority_blocking_queue_method_push
    def push(obj)
      raise ArgumentError.new('cannot enqueue nil') if obj.nil?
      synchronize { @queue.push(obj) }
      self
    end
    alias_method :<<, :push
    alias_method :enq, :push

    private

    # @!visibility private
    def pop_non_blocking
      item = synchronize { @queue.pop }
      raise ThreadError.new('queue empty') unless item
      item
    end

    # @!visibility private
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
end
