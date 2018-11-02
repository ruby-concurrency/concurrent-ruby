require 'concurrent/atomic/mutex_atomic_integer'
require 'concurrent/synchronization'

module Concurrent

  ###################################################################

  # @!macro [new] atomic_integer_method_initialize
  #
  #   Creates a new `AtomicInteger` with the given initial value.
  #
  #   @param [Integer] initial the initial value
  #   @raise [ArgumentError] if the initial value is not a `Integer`

  # @!macro [new] atomic_integer_method_value_get
  #
  #   Retrieves the current `Integer` value.
  #
  #   @return [Integer] the current value

  # @!macro [new] atomic_integer_method_value_set
  #
  #   Explicitly sets the value.
  #
  #   @param [Integer] value the new value to be set
  #
  #   @return [Integer] the current value
  #
  #   @raise [ArgumentError] if the new value is not a `Integer`

  # @!macro [new] atomic_integer_method_increment
  #
  #   Increases the current value by the given amount (defaults to 1).
  #
  #   @param [Integer] delta the amount by which to increase the current value
  #
  #   @return [Integer] the current value after incrementation

  # @!macro [new] atomic_integer_method_decrement
  #
  #   Decreases the current value by the given amount (defaults to 1).
  #
  #   @param [Integer] delta the amount by which to decrease the current value
  #
  #   @return [Integer] the current value after decrementation

  # @!macro [new] atomic_integer_method_compare_and_set
  #
  #   Atomically sets the value to the given updated value if the current
  #   value == the expected value.
  #
  #   @param [Integer] expect the expected value
  #   @param [Integer] update the new value
  #
  #   @return [Boolean] true if the value was updated else false

  # @!macro [new] atomic_integer_method_update
  #
  #   Pass the current value to the given block, replacing it
  #   with the block's result. May retry if the value changes
  #   during the block's execution.
  #
  #   @yield [Object] Calculate a new value for the atomic reference using
  #     given (old) value
  #   @yieldparam [Object] old_value the starting value of the atomic reference
  #
  #   @return [Object] the new value

  ###################################################################

  # @!macro [new] atomic_integer_public_api
  #
  #   @!method initialize(initial = 0)
  #     @!macro atomic_integer_method_initialize
  #
  #   @!method value
  #     @!macro atomic_integer_method_value_get
  #
  #   @!method value=(value)
  #     @!macro atomic_integer_method_value_set
  #
  #   @!method increment
  #     @!macro atomic_integer_method_increment
  #
  #   @!method decrement
  #     @!macro atomic_integer_method_decrement
  #
  #   @!method compare_and_set(expect, update)
  #     @!macro atomic_integer_method_compare_and_set
  #
  #   @!method update
  #     @!macro atomic_integer_method_update

  ###################################################################

  # @!visibility private
  # @!macro internal_implementation_note
  AtomicIntegerImplementation = case
                                when defined?(CAtomicInteger)
                                  CAtomicInteger
                                else
                                  MutexAtomicInteger
                                end
  private_constant :AtomicIntegerImplementation

  # @!macro [attach] atomic_integer
  #
  #   A numeric value that can be updated atomically. Reads and writes to an atomic
  #   integer and thread-safe and guaranteed to succeed. Reads and writes may block
  #   briefly but no explicit locking is required.
  #
  #   @!macro thread_safe_variable_comparison
  #
  # @!macro atomic_integer_public_api
  class AtomicInteger < AtomicIntegerImplementation
    # @return [String] Short string representation.
    def to_s
      format '%s value:%s>', super[0..-2], value
    end

    alias_method :inspect, :to_s
  end
end
