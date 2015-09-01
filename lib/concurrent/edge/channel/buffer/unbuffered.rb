require 'concurrent/edge/channel/buffer/base'
require 'concurrent/atomic/atomic_reference'

module Concurrent
  module Edge
    class Channel
      module Buffer

        # A blocking buffer with a size of zero. An item can only be put onto
        # the buffer when a thread is waiting to take. Similarly, an item can
        # only be put onto the buffer when a thread is waiting to put. When
        # either {#put} or {#take} is called and there is no corresponding call
        # in progress, the call will block indefinitely. Any other calls to the
        # same method will queue behind the first call and block as well. As
        # soon as a corresponding put/take call is made an exchange will occur
        # and the first blocked call will return.
        class Unbuffered < Base

          # @!macro channel_buffer_initialize
          def initialize
            super
            synchronize do
              # one will always be empty
              @putting = []
              @taking = []
              @closed = false
            end
          end

          # @!macro channel_buffer_size_reader
          # 
          # Always returns zero (0).
          def size() 0; end

          # @!macro channel_buffer_empty_question
          #
          # Always returns `true`.
          def empty?() true; end

          # @!macro channel_buffer_full_question
          #
          # Always returns `false`.
          def full?() false; end

          # @!macro channel_buffer_put
          #
          # Items can only be put onto the buffer when one or more threads are
          # waiting to {#take} items off the buffer. When there is a thread
          # waiting to take an item this method will give its item and return
          # immediately. When there are no threads waiting to take, this method
          # will block. As soon as a thread calls `take` the exchange will
          # occur and this method will return.
          def put(item)
            mine = synchronize do
              return false if ns_closed?

              ref = Concurrent::AtomicReference.new(item)
              if @taking.empty?
                @putting.push(ref)
              else
                taking = @taking.shift
                taking.value = item
                ref.value = nil
              end
              ref
            end
            loop do
              return true if mine.value.nil?
              Thread.pass
            end
          end

          # @!macro channel_buffer_offer
          #
          # Items can only be put onto the buffer when one or more threads are
          # waiting to {#take} items off the buffer. When there is a thread
          # waiting to take an item this method will give its item and return
          # `true` immediately. When there are no threads waiting to take or the
          # buffer is closed, this method will return `false` immediately.
          def offer(item)
            synchronize do
              return false if ns_closed? || @taking.empty?

              taking = @taking.shift
              taking.value = item
              true
            end
          end

          # @!macro channel_buffer_take
          #
          # Items can only be taken from the buffer when one or more threads are
          # waiting to {#put} items onto the buffer. When there is a thread
          # waiting to put an item this method will take that item and return it
          # immediately. When there are no threads waiting to put, this method
          # will block. As soon as a thread calls `pur` the exchange will occur
          # and this method will return.
          def take
            mine = synchronize do
              return NO_VALUE if ns_closed? && @putting.empty?

              ref = Concurrent::AtomicReference.new(nil)
              if @putting.empty?
                @taking.push(ref)
              else
                putting = @putting.shift
                ref.value = putting.value
                putting.value = nil
              end
              ref
            end
            loop do
              item = mine.value
              return item if item
              Thread.pass
            end
          end

          # @!macro channel_buffer_poll
          #
          # Items can only be taken off the buffer when one or more threads are
          # waiting to {#put} items onto the buffer. When there is a thread
          # waiting to put an item this method will take the item and return
          # it immediately. When there are no threads waiting to put or the
          # buffer is closed, this method will return `NO_VALUE` immediately.
          def poll
            synchronize do
              return NO_VALUE if @putting.empty?

              putting = @putting.shift
              value = putting.value
              putting.value = nil
              value
            end
          end

          # @!macro channel_buffer_next
          #
          # Items can only be taken from the buffer when one or more threads are
          # waiting to {#put} items onto the buffer. This method exhibits the
          # same blocking behavior as {#take}.
          #
          # @see {#take}
          def next
            item = take
            more = synchronize { !@putting.empty? }
            return item, more
          end
        end
      end
    end
  end
end
