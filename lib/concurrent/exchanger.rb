module Concurrent
  class Exchanger

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
end