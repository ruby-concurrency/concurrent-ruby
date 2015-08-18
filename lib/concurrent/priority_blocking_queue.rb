require 'concurrent/collection/mutex_priority_blocking_queue'
require 'concurrent/collection/java_priority_blocking_queue'

module Concurrent

  ###################################################################

  # @!macro [new] priority_blocking_queue_method_initialize
  #
  #   Creates a new queue.
  #
  #   When a block is given at construction the block will be used as
  #   a comparator to sort the items in the queue. The block will be
  #   passed two arguments: `this` and `that`. The block should return
  #   one of the following values: -1, 0, or 1. -1 means `this` is smaller
  #   than `that`. 0 means `this` is equal to `that`. 1 means `this` is
  #   bigger than `that`.
  #
  #   @param [Hash] opts the options controlling queue behavior.
  #   @option opts [Symbol] :order (:max) dictates the order in which items are
  #     stored: from highest to lowest when `:max` or `:high`; from lowest to
  #     highest when `:min` or `:low`
  #
  #   @yield [this, that] A block to be used as a comparator when items are
  #     inserted into the queue.
  #   @yieldparam [Object] this the item being inserted into the queue.
  #   @yieldparam [Object] an item in the queue to which the item is being compared.
  #   @yieldreturn [Integer] -1, 0, or 1 indicating the result of the comparison.
  #
  #   @example Natural Ordering
  #
  #     q = Concurrent::PriorityBlockingQueue.new
  #
  #     [2, 1, 4, 5, 3, 0].each{|item| q.push(item) }
  #
  #     q.pop #=> 5
  #     q.pop #=> 4
  #     q.pop #=> 3
  #
  #   @example Explicit Ordering
  #
  #     q = Concurrent::PriorityBlockingQueue.new(order: :low)
  #
  #     [2, 1, 4, 5, 3, 0].each{|item| q.push(item) }
  #
  #     q.pop #=> 0
  #     q.pop #=> 1
  #     q.pop #=> 2
  #
  #   @example Ordering With Block Comparator
  #
  #     q = Concurrent::PriorityBlockingQueue do |this, that|
  #       this.to_s.length <=> that.to_s.length
  #     end
  #
  #     %w[aaa b cccc dd eeeee].each{|item| q.push(item) }
  #
  #     q.pop #=> 'eeeee'
  #     q.pop #=> 'cccc'
  #     q.pop #=> 'aaa'
  #
  #   @see http://ruby-doc.org/core-2.2.2/Object.html#method-i-3C-3D-3E Ruby `Object#<=>` method
  
  # @!macro [new] priority_blocking_queue_method_clear
  #
  #   Removes all objects from the queue.
  #
  #   @return [Concurrent::PriorityBlockingQueue] self
  
  # @!macro [new] priority_blocking_queue_method_empty_question
  #
  #   Returns true if the queue is empty.
  #
  #   @return [Object] true if the queue is empty else false.
  
  # @!macro [new] priority_blocking_queue_method_length
  #
  #   Returns the length of the queue.
  #
  #   @return [Integer] the length of the queue.
  
  # @!macro [new] priority_blocking_queue_method_num_waiting
  #
  #   Returns the number of threads waiting on the queue.
  #
  #   @return [Integer] the number of threads waiting on the queue.
  
  # @!macro [new] priority_blocking_queue_method_poll
  #
  #   Retrieves data from the queue. When no `timeout` is given and the queue
  #   is empty the method will return `nil` immediately. When a `timeout`
  #   value is given and the queue is empty the calling thread is suspended
  #   until data is pushed onto the queue or until the timeout is reached,
  #   whichever comes first.
  #
  #   @param [Integer] timeout the maximum number of seconds to wait for
  #     an item to be returned.
  #   @return [Object, nil] the item removed from the head of the queue
  #     or nil if the queue is empty when the method returns.
  
  # @!macro [new] priority_blocking_queue_method_pop
  #
  #   Retrieves data from the queue. If the queue is empty, the calling thread
  #   is suspended until data is pushed onto the queue. If `non_block` is true,
  #   the thread isn’t suspended, and an exception is raised.
  #
  #   @return [Object] the item removed from the head of the queue.
  #   @raise [ThreadError] when the queue is empty and `non_block` is true.
  
  # @!macro [new] priority_blocking_queue_method_push
  #
  #   Pushes an object onto the queue. The object will be placed within
  #   the queue based on its priority relative to the other itmes in
  #   the queue and the sort order specified at construction.
  #
  #   @param [Object] obj the object to be pushed onto the queue.
  #   @return [Concurrent::PriorityBlockingQueue] self

  ###################################################################

  # @!macro [new] priority_blocking_queue_public_api
  #
  #   @!method initialize(opts = {})
  #     @!macro priority_blocking_queue_method_initialize
  #
  #   @!method clear
  #     @!macro priority_blocking_queue_method_clear
  #
  #   @!method empty?
  #     @!macro priority_blocking_queue_method_empty_question
  #
  #   @!method length
  #     @!macro priority_blocking_queue_method_length
  #
  #   @!method num_waiting
  #     @!macro priority_blocking_queue_method_num_waiting
  #
  #   @!method poll(timeout = nil)
  #     @!macro priority_blocking_queue_method_poll
  #
  #   @!method pop(non_block = false)
  #     @!macro priority_blocking_queue_method_pop
  #
  #   @!method push(obj)
  #     @!macro priority_blocking_queue_method_push

  ###################################################################

  # @!visibility private
  # @!macro internal_implementation_note
  PriorityBlockingQueueImplementation = case
                                        when Concurrent.on_jruby?
                                          JavaPriorityBlockingQueue
                                        else
                                          MutexPriorityBlockingQueue
                                        end
  private_constant :PriorityBlockingQueueImplementation

  # @!macro [attach] priority_blocking_queue
  #
  #   A stand-in replacement for Ruby's `Queue` class that prioritizes placement
  #   within the queue. It provides a mechanism for synchronizing between threads.
  #
  #   It is an unbounded priority queue based on a priority heap. The elements
  #   of the queue are ordered according to their natural ordering, or by a block
  #   comparator provided at construction. A priority queue does not permit `nil` items.
  #
  #   @see http://ruby-doc.org/stdlib-2.0.0/libdoc/thread/rdoc/Queue.html Ruby Queue
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/PriorityQueue.html Java PriorityQueue
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/PriorityBlockingQueue.html Java PriorityBlockingQueue
  #
  # @!macro priority_blocking_queue_public_api
  class PriorityBlockingQueue < PriorityBlockingQueueImplementation

    alias_method :size, :length

    alias_method :deq, :pop
    alias_method :shift, :pop

    alias_method :<<, :push
    alias_method :enq, :push
  end
end
