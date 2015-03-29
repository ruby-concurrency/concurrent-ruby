module Concurrent

  # A synchronization point at which threads can pair and swap elements within
  # pairs. Each thread presents some object on entry to the exchange method,
  # matches with a partner thread, and receives its partner's object on return.
  #
  # Uses `MVar` to manage synchronization of the individual elements.
  # Since `MVar` is also a `Dereferenceable`, the exchanged values support all
  # dereferenceable options. The constructor options hash will be passed to
  # the `MVar` constructors.
  # 
  # @see Concurrent::MVar
  # @see Concurrent::Dereferenceable
  # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Exchanger.html java.util.concurrent.Exchanger
  class MVarExchanger

    EMPTY = Object.new

    # Create a new `Exchanger` object.
    #
    # @param [Hash] opts the options controlling how the managed references
    #   will be processed
    def initialize(opts = {})
      @first = MVar.new(EMPTY, opts)
      @second = MVar.new(MVar::EMPTY, opts)
    end

    # Waits for another thread to arrive at this exchange point (unless the
    # current thread is interrupted), and then transfers the given object to
    # it, receiving its object in return.
    #
    # @param [Object] value the value to exchange with an other thread
    # @param [Numeric] timeout the maximum time in second to wait for one other
    #   thread. nil (default value) means no timeout
    # @return [Object] the value exchanged by the other thread; nil if timed out
    def exchange(value, timeout = nil)

      # Both threads modify the first variable
      first_result = @first.modify(timeout) do |first|
        # Does it currently contain the special empty value?
        if first == EMPTY
          # If so, modify it to contain our value
          value
        else
          # Otherwise, modify it back to the empty state
          EMPTY
        end
      end

      # If that timed out, the whole operation timed out
      return nil if first_result == MVar::TIMEOUT

      # What was in @first before we modified it?
      if first_result == EMPTY
        # We stored our object - someone else will turn up with the second
        # object at some point in the future

        # Wait for the second object to appear
        second_result = @second.take(timeout)

        # If that timed out, the whole operation timed out
        return nil if second_result == MVar::TIMEOUT

        # BUT HOW DO WE CANCEL OUR RESULT BEING AVAILABLE IN @first?

        # Return that second object
        second_result
      else
        # We reset @first to be empty again - so the other value is in
        # first_result and we need to tell the other thread about our value

        # Tell the other thread about our object
        second_result = @second.put(value, timeout)

        # If that timed out, the whole operation timed out
        return nil if second_result == MVar::TIMEOUT

        # We already have its object
        first_result
      end
    end
  end

  class SlotExchanger

    def initialize
      @mutex = Mutex.new
      @condition = Condition.new
      @slot = new_slot
    end

    def exchange(value, timeout = nil)
      @mutex.synchronize do

        replace_slot_if_fulfilled

        slot = @slot

        if slot.state == :empty
          slot.value_1 = value
          slot.state = :waiting
          wait_for_value(slot, timeout)
          slot.value_2
        else
          slot.value_2 = value
          slot.state = :fulfilled
          @condition.broadcast
          slot.value_1
        end
      end
    end

    Slot = Struct.new(:value_1, :value_2, :state)

    private_constant :Slot

    private

    def replace_slot_if_fulfilled
      @slot = new_slot if @slot.state == :fulfilled
    end

    def wait_for_value(slot, timeout)
      remaining = Condition::Result.new(timeout)
      while slot.state == :waiting && remaining.can_wait?
        remaining = @condition.wait(@mutex, remaining.remaining_time)
      end
    end

    def new_slot
      Slot.new(nil, nil, :empty)
    end
  end

  Exchanger = SlotExchanger

end
