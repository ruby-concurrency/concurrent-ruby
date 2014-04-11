module Concurrent

  # @!macro [attach] priority_queue
  #
  # @see http://ruby-doc.org/stdlib-2.0.0/libdoc/thread/rdoc/Queue.html
  # @see http://en.wikipedia.org/wiki/Priority_queue
  class MutexPriorityQueue

    def initialize(opts = {})
    end

    def clear
    end

    def delete(item)
    end

    def empty?
    end

    def include?(item)
    end
    alias_method :has_priority?, :include?

    def length
    end
    alias_method :size, :length

    def peek
    end
    alias_method :next, :peek

    def pop
    end
    alias_method :deq, :pop
    alias_method :shift, :pop
    alias_method :next!, :pop

    def push(item)
    end
    alias_method :<<, :push
    alias_method :enq, :push

    def to_a
    end

    def self.from_list(list)
    end
  end

  if RUBY_PLATFORM == 'java'

    # @!macro priority_queue
    #
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/PriorityQueue.html
    class JavaPriorityQueue

      def initialize(opts = {})
        order = opts.fetch(:order, :max)
        if [:min, :low].include?(order)
          @queue = java.util.PriorityQueue.new(11) # 11 is the default initial capacity
        else
          @queue = java.util.PriorityQueue.new(11, java.util.Collections.reverseOrder())
        end
      end

      def clear
        @queue.clear
        true
      end

      def delete(item)
        @queue.remove(item)
      end

      def empty?
        @queue.size == 0
      end

      def include?(item)
        @queue.contains(item)
      end
      alias_method :has_priority?, :include?

      def length
        @queue.size
      end
      alias_method :size, :length

      def peek
        @queue.peek
      end

      def pop
        @queue.poll
      end
      alias_method :deq, :pop
      alias_method :shift, :pop

      def push(item)
        @queue.add(item)
      end
      alias_method :<<, :push
      alias_method :enq, :push

      def self.from_list(list, opts = {})
        queue = JavaPriorityQueue.new(opts)
        list.each{|item| queue << item }
        queue
      end
    end

    # @!macro priority_queue
    class PriorityQueue < JavaPriorityQueue
    end
  else

    # @!macro priority_queue
    class PriorityQueue < MutexPriorityQueue
    end
  end
end
