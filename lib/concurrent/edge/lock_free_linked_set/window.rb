module Concurrent
  module Edge
    class Window
      attr_accessor :pred, :curr

      def initialize(pred, curr)
        @pred, @curr = pred, curr
      end

      # This method is used to find a 'window' for which `add` and `remove`
      # methods can use to know where to add and remove from the list. However,
      # it has another responsibilility, which is to physically unlink any
      # nodes marked for removal in the set. This prevents adds/removes from
      # having to retraverse the list to physically unlink nodes.
      def self.find(head, item)
        loop do
          break_inner_loops = false
          pred = head
          curr = pred.next

          loop do
            succ, marked = curr.succ.get

            # Remove sequence of marked nodes
            while marked
              removed = pred.succ.compare_and_set curr, succ, false, false

              # If could not remove node, try again
              break_inner_loops = true && break unless removed

              curr = succ
              succ, marked = curr.succ.get
            end

            break if break_inner_loops

            # We have found a window
            return new pred, curr if curr >= item

            pred = curr
            curr = succ
          end
        end
      end
    end
  end
end
