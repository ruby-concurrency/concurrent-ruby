module Concurrent
  module Collection

    # @!macro priority_queue
    #
    # @note This implementation is *not* thread safe.
    # 
    # @!visibility private
    # @!macro internal_implementation_note
    class RubyNonConcurrentPriorityQueue

      # @!macro priority_queue_method_initialize
      def initialize(opts = {})
        order = opts.fetch(:order, :max)
        @comparator = [:min, :low].include?(order) ? -1 : 1
        clear
      end

      # @!macro priority_queue_method_clear
      def clear
        @queue = [nil]
        @length = 0
        true
      end

      # @!macro priority_queue_method_delete
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

      # @!macro priority_queue_method_empty
      def empty?
        length == 0
      end

      # @!macro priority_queue_method_include
      def include?(item)
        @queue.include?(item)
      end
      #alias_method :has_priority?, :include?

      # @!macro priority_queue_method_length
      def length
        @length
      end
      #alias_method :size, :length

      # @!macro priority_queue_method_peek
      def peek
        @queue[1]
      end

      # @!macro priority_queue_method_pop
      def pop
        max = @queue[1]
        swap(1, @length)
        @length -= 1
        sink(1)
        @queue.pop
        max
      end
      #alias_method :deq, :pop
      #alias_method :shift, :pop

      # @!macro priority_queue_method_push
      def push(item)
        @length += 1
        @queue.push item
        swim(@length)
        true
      end
      #alias_method :<<, :push
      #alias_method :enq, :push

      # @!macro priority_queue_method_from_list
      def self.from_list(list, opts = {})
        queue = new(opts)
        list.each{|item| queue.push item }
        queue
      end

      protected

      # Exchange the values at the given indexes within the internal array.
      # 
      # @param [Integer] x the first index to swap
      # @param [Integer] y the second index to swap
      # 
      # @!visibility private
      def swap(x, y)
        temp = @queue[x]
        @queue[x] = @queue[y]
        @queue[y] = temp
      end

      # Are the items at the given indexes ordered based on the priority
      # order specified at construction?
      #
      # @param [Integer] x the first index from which to retrieve a comparable value
      # @param [Integer] y the second index from which to retrieve a comparable value
      #
      # @return [Boolean] true if the two elements are in the correct priority order
      #   else false
      # 
      # @!visibility private
      def ordered?(x, y)
        (@queue[x] <=> @queue[y]) == @comparator
      end

      # Percolate down to maintain heap invariant.
      # 
      # @param [Integer] k the index at which to start the percolation
      # 
      # @!visibility private
      def sink(k)
        while (j = (2 * k)) <= @length do
          j += 1 if j < @length && ! ordered?(j, j+1)
          break if ordered?(k, j)
          swap(k, j)
          k = j
        end
      end

      # Percolate up to maintain heap invariant.
      # 
      # @param [Integer] k the index at which to start the percolation
      # 
      # @!visibility private
      def swim(k)
        while k > 1 && ! ordered?(k/2, k) do
          swap(k, k/2)
          k = k/2
        end
      end
    end

    if Concurrent.on_jruby?

      # @!macro priority_queue
      # 
      # @!visibility private
      # @!macro internal_implementation_note
      class JavaNonConcurrentPriorityQueue

        # @!macro priority_queue_method_initialize
        def initialize(opts = {})
          order = opts.fetch(:order, :max)
          if [:min, :low].include?(order)
            @queue = java.util.PriorityQueue.new(11) # 11 is the default initial capacity
          else
            @queue = java.util.PriorityQueue.new(11, java.util.Collections.reverseOrder())
          end
        end

        # @!macro priority_queue_method_clear
        def clear
          @queue.clear
          true
        end

        # @!macro priority_queue_method_delete
        def delete(item)
          found = false
          while @queue.remove(item) do
            found = true
          end
          found
        end

        # @!macro priority_queue_method_empty
        def empty?
          @queue.length == 0
        end

        # @!macro priority_queue_method_include
        def include?(item)
          @queue.contains(item)
        end
        #alias_method :has_priority?, :include?

        # @!macro priority_queue_method_length
        def length
          @queue.size
        end
        #alias_method :size, :length

        # @!macro priority_queue_method_peek
        def peek
          @queue.peek
        end

        # @!macro priority_queue_method_pop
        def pop
          @queue.poll
        end
        #alias_method :deq, :pop
        #alias_method :shift, :pop

        # @!macro priority_queue_method_push
        def push(item)
          @queue.add(item)
        end
        #alias_method :<<, :push
        #alias_method :enq, :push

        # @!macro priority_queue_method_from_list
        def self.from_list(list, opts = {})
          queue = new(opts)
          list.each{|item| queue.push item }
          queue
        end
      end
    end

    # @!visibility private
    # @!macro internal_implementation_note
    NonConcurrentPriorityQueueImplementation = case
                                               when Concurrent.on_jruby?
                                                 JavaNonConcurrentPriorityQueue
                                               else
                                                 RubyNonConcurrentPriorityQueue
                                               end
    private_constant :NonConcurrentPriorityQueueImplementation

    # @!macro priority_queue
    # 
    # @!visibility private
    class NonConcurrentPriorityQueue < NonConcurrentPriorityQueueImplementation

      #alias_method :has_priority?, :include?

      #alias_method :size, :length

      #alias_method :deq, :pop
      #alias_method :shift, :pop

      #alias_method :<<, :push
      #alias_method :enq, :push

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
