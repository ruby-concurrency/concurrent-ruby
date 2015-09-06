require 'concurrent/synchronization'

module Concurrent

  # @!macro atomic_fixnum
  # @!visibility private
  # @!macro internal_implementation_note
  class MutexAtomicFixnum < Synchronization::LockableObject

    # http://stackoverflow.com/questions/535721/ruby-max-integer
    MIN_VALUE = -(2**(0.size * 8 - 2))
    MAX_VALUE = (2**(0.size * 8 - 2) - 1)

    # @!macro atomic_fixnum_method_initialize
    def initialize(initial = 0)
      super()
      synchronize { ns_initialize(initial) }
    end

    # @!macro atomic_fixnum_method_value_get
    def value
      synchronize { @value }
    end

    # @!macro atomic_fixnum_method_value_set
    def value=(value)
      synchronize { ns_set(value) }
    end

    # @!macro atomic_fixnum_method_increment
    def increment(delta = 1)
      synchronize { ns_set(@value + delta.to_i) }
    end

    alias_method :up, :increment

    # @!macro atomic_fixnum_method_decrement
    def decrement(delta = 1)
      synchronize { ns_set(@value - delta.to_i) }
    end

    alias_method :down, :decrement

    # @!macro atomic_fixnum_method_compare_and_set
    def compare_and_set(expect, update)
      synchronize do
        if @value == expect.to_i
          @value = update.to_i
          true
        else
          false
        end
      end
    end

    # @!macro atomic_fixnum_method_update
    def update
      synchronize do
        @value = yield @value
      end
    end

    protected

    # @!visibility private
    def ns_initialize(initial)
      ns_set(initial)
    end

    private

    # @!visibility private
    def ns_set(value)
      range_check!(value)
      @value = value
    end

    # @!visibility private
    def range_check!(value)
      if !value.is_a?(Fixnum)
        raise ArgumentError.new('value value must be a Fixnum')
      elsif value > MAX_VALUE
        raise RangeError.new("#{value} is greater than the maximum value of #{MAX_VALUE}")
      elsif value < MIN_VALUE
        raise RangeError.new("#{value} is less than the maximum value of #{MIN_VALUE}")
      else
        value
      end
    end
  end
end
