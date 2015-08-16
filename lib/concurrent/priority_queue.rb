require 'concurrent/collection/non_concurrent_priority_queue'
require 'concurrent/synchronization/object'

module Concurrent

  # @!macro [attach] priority_queue
  #
  #   A queue collection in which the elements are sorted based on their
  #   comparison (spaceship) operator `<=>`. Items are added to the queue
  #   at a position relative to their priority. On removal the element
  #   with the "highest" priority is removed. By default the sort order is
  #   from highest to lowest, but a lowest-to-highest sort order can be
  #   set on construction.
  #
  #   The API is based on the `Queue` class from the Ruby standard library.
  #
  #   The pure Ruby implementation uses a heap algorithm stored in an array.
  #   The algorithm is based on the work of Robert Sedgewick and Kevin Wayne.
  #
  #   The JRuby native implementation is a thin wrapper around the standard
  #   library `java.util.NonConcurrentPriorityQueue`.
  #
  #   @see http://en.wikipedia.org/wiki/Priority_queue
  #   @see http://ruby-doc.org/stdlib-2.0.0/libdoc/thread/rdoc/Queue.html
  #
  #   @see http://algs4.cs.princeton.edu/24pq/index.php#2.6
  #   @see http://algs4.cs.princeton.edu/24pq/MaxPQ.java.html
  #
  #   @see http://docs.oracle.com/javase/7/docs/api/java/util/NonConcurrentPriorityQueue.html
  class PriorityQueue < Synchronization::Object

    # @!macro [attach] priority_queue_method_initialize
    #
    #   Create a new priority queue with no items.
    #  
    #   @param [Hash] opts the options for creating the queue
    #   @option opts [Symbol] :order (:max) dictates the order in which items are
    #     stored: from highest to lowest when `:max` or `:high`; from lowest to
    #     highest when `:min` or `:low`
    def initialize(opts = {})
      super()
      synchronize do
        @q = Concurrent::Collection::NonConcurrentPriorityQueue.new(opts)
      end
    end

    # @!macro [attach] priority_queue_method_clear
    #
    #   Removes all of the elements from this priority queue.
    def clear
      synchronize { @q.clear }
    end

    # @!macro [attach] priority_queue_method_delete
    #
    #   Deletes all items from `self` that are equal to `item`.
    #  
    #   @param [Object] item the item to be removed from the queue
    #   @return [Object] true if the item is found else false
    def delete(item)
      synchronize { @q.delete(item) }
    end

    # @!macro [attach] priority_queue_method_empty
    #  
    #   Returns `true` if `self` contains no elements.
    #  
    #   @return [Boolean] true if there are no items in the queue else false
    def empty?
      synchronize { @q.empty? }
    end

    # @!macro [attach] priority_queue_method_include
    #
    #   Returns `true` if the given item is present in `self` (that is, if any
    #   element == `item`), otherwise returns false.
    #  
    #   @param [Object] item the item to search for
    #  
    #   @return [Boolean] true if the item is found else false
    def include?(item)
      synchronize { @q.include?(item) }
    end
    alias_method :has_priority?, :include?

    # @!macro [attach] priority_queue_method_length
    #  
    #   The current length of the queue.
    #  
    #   @return [Fixnum] the number of items in the queue
    def length
      synchronize { @q.length }
    end
    alias_method :size, :length

    # @!macro [attach] priority_queue_method_peek
    #  
    #   Retrieves, but does not remove, the head of this queue, or returns `nil`
    #   if this queue is empty.
    #   
    #   @return [Object] the head of the queue or `nil` when empty
    def peek
      synchronize { @q.peek }
    end

    # @!macro [attach] priority_queue_method_pop
    #  
    #   Retrieves and removes the head of this queue, or returns `nil` if this
    #   queue is empty.
    #   
    #   @return [Object] the head of the queue or `nil` when empty
    def pop
      synchronize { @q.pop }
    end
    alias_method :deq, :pop
    alias_method :shift, :pop

    # @!macro [attach] priority_queue_method_push
    #  
    #   Inserts the specified element into this priority queue.
    #  
    #   @param [Object] item the item to insert onto the queue
    def push(item)
      synchronize { @q.push(item) }
    end
    alias_method :<<, :push
    alias_method :enq, :push

    # @!macro [attach] priority_queue_method_from_list
    #  
    #   Create a new priority queue from the given list.
    #  
    #   @param [Enumerable] list the list to build the queue from
    #   @param [Hash] opts the options for creating the queue
    #  
    #   @return [NonConcurrentPriorityQueue] the newly created and populated queue
    def self.from_list(list, opts = {})
      q = Concurrent::Collection::NonConcurrentPriorityQueue.from_list(list, opts)
      queue = new(opts)
      queue.instance_variable_set(:@q, q)
      queue
    end
  end
end
