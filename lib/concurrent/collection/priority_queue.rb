require 'concurrent/collection/priority_queue_impl/java_priority_queue'
require 'concurrent/collection/priority_queue_impl/mutex_priority_queue'

module Concurrent
  module Collection

    module PriorityQueueImpl
      Implementation = case
                       when Concurrent.on_jruby?
                         JavaPriorityQueue
                       else
                         MutexPriorityQueue
                       end
    end

    # @!macro priority_queue
    class PriorityQueue < PriorityQueueImpl::Implementation

      alias_method :has_priority?, :include?

      alias_method :size, :length

      alias_method :deq, :pop
      alias_method :shift, :pop

      alias_method :<<, :push
      alias_method :enq, :push

      # @!method initialize(opts = {})
      #   @!macro priority_queue_method_initialize

      # @!method clear
      #   @!macro priority_queue_method_clear

      # @!method delete(item)
      #   @!macro priority_queue_method_delete

      # @!method empty?
      #   @!macro priority_queue_method_empty

      # @!method include?(item)
      #   @!macro priority_queue_method_include

      # @!method length
      #   @!macro priority_queue_method_length

      # @!method peek
      #   @!macro priority_queue_method_peek

      # @!method pop
      #   @!macro priority_queue_method_pop

      # @!method push(item)
      #   @!macro priority_queue_method_push

      # @!method self.from_list(list, opts = {})
      #   @!macro priority_queue_method_from_list
    end
  end
end
