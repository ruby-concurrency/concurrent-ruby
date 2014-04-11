module Concurrent

  # @!macro [attach] priority_queue
  #
  # @see http://ruby-doc.org/stdlib-2.0.0/libdoc/thread/rdoc/Queue.html
  # @see http://en.wikipedia.org/wiki/Priority_queue
  # @see http://algs4.cs.princeton.edu/24pq/MaxPQ.java.html
  class MutexPriorityQueue

    attr_reader :length
    alias_method :size, :length

    def initialize(opts = {})
      order = opts.fetch(:order, :max)
      @comparator = [:min, :low].include?(order) ? 1 : -1
      clear
    end

    def clear
      @queue = [nil]
      @length = 0
      true
    end

    def delete(item)
      original_length = @length
      k = 1
      while k <= @length
        if @queue[k] == item
          swap(k, @length)
          @length -= 1
          sink(k)
          @queue.pop
        else
          k += 1
        end
      end
      @length != original_length
    end

    def empty?
      size == 0
    end

    def include?(item)
      @queue.include?(item)
    end
    alias_method :has_priority?, :include?

    def peek
      @queue[1]
    end

    def pop
      max = @queue[1]
      swap(1, @length)
      @length -= 1
      sink(1)
      @queue.pop
      max
    end
    alias_method :deq, :pop
    alias_method :shift, :pop

    def push(item)
      @length += 1
      @queue << item
      swim(@length)
      true
    end
    alias_method :<<, :push
    alias_method :enq, :push

    def self.from_list(list, opts = {})
      queue = new(opts)
      list.each{|item| queue << item }
      queue
    end

    protected

    def swap(x, y)
      temp = @queue[x]
      @queue[x] = @queue[y]
      @queue[y] = temp
    end

    def prioritize?(x, y)
      (@queue[x] <=> @queue[y]) == @comparator
    end

    def sink(k)
      while (j = (2 * k)) <= @length do
        j += 1 if j < @length && prioritize?(j, j+1)
        break unless prioritize?(k, j)
        swap(k, j)
        k = j
      end
    end

    def swim(k)
      while k > 1 && prioritize?(k/2, k) do
        swap(k, k/2)
        k = k/2
      end
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
        found = false
        while @queue.remove(item) do
          found = true
        end
        found
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
        queue = new(opts)
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
