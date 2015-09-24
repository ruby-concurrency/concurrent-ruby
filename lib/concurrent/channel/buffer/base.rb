require 'concurrent/synchronization/lockable_object'

module Concurrent
  class Channel
    module Buffer

      # Placeholder for when a buffer slot contains no value.
      NO_VALUE = Object.new

      # Abstract base class for all Channel buffers.
      #
      # {Concurrent::Channel} objects maintain an internal, queue-like
      # object called a buffer. It's the storage bin for values put onto or
      # taken from the channel. Different buffer types have different
      # characteristics. Subsequently, the behavior of any given channel is
      # highly dependent uping the type of its buffer. This is the base class
      # which defines the common buffer interface. Any class intended to be
      # used as a channel buffer should extend this class.
      class Base < Synchronization::LockableObject

        # @!macro [attach] channel_buffer_size_reader
        #
        #   The maximum number of values which can be {#put} onto the buffer
        #   it becomes full.
        attr_reader :size
        alias_method :capacity, :size

        # @!macro [attach] channel_buffer_initialize
        #
        #   Creates a new buffer.
        def initialize
          super()
          synchronize do
            @closed = false
            @size = 0
          end
        end

        # @!macro [attach] channel_buffer_blocking_question
        #
        #   Predicate indicating if this buffer will block {#put} operations
        #   once it reaches its maximum capacity.
        #
        #   @return [Boolean] true if this buffer blocks else false
        def blocking?
          true
        end

        # @!macro [attach] channel_buffer_empty_question
        #
        #   Predicate indicating if the buffer is empty.
        #
        #   @return [Boolean] true if this buffer is empty else false
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def empty?
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_full_question
        #
        #   Predicate indicating if the buffer is full.
        #
        #   @return [Boolean] true if this buffer is full else false
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def full?
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_put
        #
        #   Put an item onto the buffer if possible. If the buffer is open
        #   but not able to accept the item the calling thread will block
        #   until the item can be put onto the buffer.
        #
        #   @param [Object] item the item/value to put onto the buffer.
        #   @return [Boolean] true if the item was added to the buffer else
        #     false (always false when closed).
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def put(item)
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_offer
        #
        #   Put an item onto the buffer is possible. If the buffer is open but
        #   unable to add an item, probably due to being full, the method will
        #   return immediately. Similarly, the method will return immediately
        #   when the buffer is closed. A return value of `false` does not
        #   necessarily indicate that the buffer is closed, just that the item
        #   could not be added.
        #
        #   @param [Object] item the item/value to put onto the buffer.
        #   @return [Boolean] true if the item was added to the buffer else
        #     false (always false when closed).
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def offer(item)
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_take
        #
        #   Take an item from the buffer if one is available. If the buffer
        #   is open and no item is available the calling thread will block
        #   until an item is available. If the buffer is closed but items
        #   are available the remaining items can still be taken. Once the
        #   buffer closes, no remaining items can be taken.
        #
        #   @return [Object] the item removed from the buffer; `NO_VALUE` once
        #     the buffer has closed.
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def take
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_next
        #
        #   Take the next item from the buffer and also return a boolean
        #   indicating if subsequent items can be taken. Used for iterating
        #   over a buffer until it is closed and empty.
        #
        #   If the buffer is open but no items remain the calling thread will
        #   block until an item is available. The second of the two return
        #   values, a boolean, will always be `true` when the buffer is open.
        #   When the buffer is closed but more items remain the second return
        #   value will also be `true`. When the buffer is closed and the last
        #   item is taken the second return value will be `false`. When the
        #   buffer is both closed and empty the first return value will be
        #   `NO_VALUE` and the second return value will be `false`.
        #   be `false` when the buffer is both closed and empty.
        #
        #   Note that when multiple threads access the same channel a race
        #   condition can occur when using this method. A call to `next` from
        #   one thread may return `true` for the second return value, but
        #   another thread may `take` the last value before the original
        #   thread makes another call. Code which iterates over a channel
        #   must be programmed to properly handle these race conditions.
        #
        #   @return [Object, Boolean] the first return value will be the item
        #     taken from the buffer and the second return value will be a
        #     boolean indicating whether or not more items remain.
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def next
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_poll
        #
        #   Take the next item from the buffer if one is available else return
        #   immediately. Failing to return a value does not necessarily
        #   indicate that the buffer is closed, just that it is empty.
        #
        #   @return [Object] the next item from the buffer or `NO_VALUE` if
        #     the buffer is empty.
        #
        # @raise [NotImplementedError] until overridden in a subclass.
        def poll
          raise NotImplementedError
        end

        # @!macro [attach] channel_buffer_close
        #
        #   Close the buffer, preventing new items from being added. Once a
        #   buffer is closed it cannot be opened again.
        #
        #   @return [Boolean] true if the buffer was open and successfully
        #     closed else false.
        def close
          synchronize do
            @closed ? false : @closed = true
          end
        end

        # @!macro [attach] channel_buffer_closed_question
        #
        #   Predicate indicating is this buffer closed.
        #
        #   @return [Boolea] true when closed else false.
        def closed?
          synchronize { ns_closed? }
        end

        private

        # @!macro channel_buffer_closed_question
        def ns_closed?
          @closed
        end
      end
    end
  end
end
