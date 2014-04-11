module Concurrent

  # @!macro [attach] priority_queue
  #
  # @see http://ruby-doc.org/stdlib-2.0.0/libdoc/thread/rdoc/Queue.html
  # @see http://en.wikipedia.org/wiki/Priority_queue
  class MutexPriorityQueue

    def initialize(initial_capackty = 0)
    end

    def clear
    end

    def empty?
    end

    def length
    end
    alias_method :size, :length

    def num_waiting() -1; end

    def peek
    end

    def pop(non_block = false)
    end
    alias_method :deq, :pop
    alias_method :shift, :pop

    def push(item)
    end
    alias_method :<<, :push
    alias_method :enq, :push
  end

  if RUBY_PLATFORM == 'java'

    # @!macro priority_queue
    #
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/PriorityQueue.html
    class JavaPriorityQueue

      def initialize(initial_capackty = 0)
      end

      def clear
      end

      def empty?
      end

      def length
      end
      alias_method :size, :length

      def num_waiting() -1; end

      def peek
      end

      def pop(non_block = false)
      end
      alias_method :deq, :pop
      alias_method :shift, :pop

      def push(item)
      end
      alias_method :<<, :push
      alias_method :enq, :push
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
