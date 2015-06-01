require 'concurrent/edge/lock_free_linked_set/node'
require 'concurrent/edge/lock_free_linked_set/window'

module Concurrent
  module Edge
    class LockFreeLinkedSet
      include Enumerable

      # @!macro [attach] lock_free_linked_list_method_initialize
      #
      # @param [Fixnum] initial_size the size of the linked_list to initialize
      def initialize(initial_size = 0, val = nil)
        @head = Head.new

        initial_size.times do
          val = block_given? ? yield : val

          self.add val
        end
      end

      # @!macro [attach] lock_free_linked_list_method_add
      #
      #   Atomically adds the item to the set if it does not yet exist. Note:
      #   internally the set uses `Object#hash` to compare equality of items,
      #   meaning that Strings and other objects will be considered equal
      #   despite being different objects.
      #
      #   @param [Object] item the item you wish to insert
      #
      #   @return [Boolean] `true` if successful. A `false` return indicates
      #   that the item was already in the set.
      def add(item)
        loop do
          window = Window.find @head, item

          pred, curr = window.pred, window.curr

          # Item already in set
          if curr == item
            return false
          else
            node = Node.new item, curr

            return true if pred.succ.compare_and_set curr, node, false, false
          end
        end
      end

      # @!macro [attach] lock_free_linked_list_method_<<
      #
      #   Atomically adds the item to the set if it does not yet exist.
      #
      #   @param [Object] item the item you wish to insert
      #
      #   @return [Oject] the set on which the :<< method was invoked
      def <<(item)
        self if add item
      end

      # @!macro [attach] lock_free_linked_list_method_contains
      #
      #   Atomically checks to see if the set contains an item. This method
      #   compares equality based on the `Object#hash` method, meaning that the
      #   hashed contents of an object is what determines equality instead of
      #   `Object#object_id`
      #
      #   @param [Object] item the item you to check for presence in the set
      #
      #   @return [Boolean] whether or not the item is in the set
      def contains?(item)
        curr = @head

        while curr < item
          curr = curr.next
          marked = curr.succ.marked?
        end

        curr == item && !marked
      end

      # @!macro [attach] lock_free_linked_list_method_remove
      #
      #   Atomically attempts to remove an item, comparing using `Object#hash`.
      #
      #   @param [Object] item the item you to remove from the set
      #
      #   @return [Boolean] whether or not the item was removed from the set
      def remove(item)
        loop do
          window = Window.find @head, item
          pred, curr = window.pred, window.curr

          if curr != item
            return false
          else
            succ = curr.next
            snip = curr.succ.compare_and_set succ, succ, false, true

            next unless snip

            pred.succ.compare_and_set curr, succ, false, false

            return true
          end
        end
      end

      # @!macro [attach] lock_free_linked_list_method_each
      #
      #   An iterator to loop through the set.
      #
      #   @param [Object] item the item you to remove from the set
      #   @yeild [Object] each item in the set
      #
      #   @return [Object] self: the linked set on which each was called
      def each
        return to_enum unless block_given?

        curr = @head

        until curr.last?
          curr = curr.next
          marked = curr.succ.marked?

          yield curr.data if !marked
        end

        self
      end
    end
  end
end
