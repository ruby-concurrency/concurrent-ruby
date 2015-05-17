module Concurrent
  module Edge
    class LockFreeStack < Synchronization::Object

      Node = ImmutableStruct.new(:value, :next) do
        singleton_class.send :alias_method, :[], :new
      end

      class Empty < Node
        def next
          self
        end
      end

      EMPTY = Empty[nil, nil]

      def initialize
        super()
        @Head = AtomicReference.new EMPTY
        ensure_ivar_visibility!
      end

      def empty?
        @Head.get.equal? EMPTY
      end

      def compare_and_push(head, value)
        @Head.compare_and_set head, Node[value, head]
      end

      def push(value)
        @Head.update { |head| Node[value, head] }
        self
      end

      def peek
        @Head.get
      end

      def compare_and_pop(head)
        @Head.compare_and_set head, head.next
      end

      def pop
        popped = nil
        @Head.update { |head| (popped = head).next }
        popped.value
      end

      def compare_and_clear(head)
        @Head.compare_and_set head, EMPTY
      end

      def clear
        @Head.update { |_| EMPTY }
        self
      end

      include Enumerable

      def each
        return to_enum unless block_given?
        it = peek
        until it.equal?(EMPTY)
          yield it.value
          it = it.next
        end
        self
      end

    end
  end
end
