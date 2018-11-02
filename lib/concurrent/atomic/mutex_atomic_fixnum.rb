require 'concurrent/atomic/mutex_atomic_integer'
require 'concurrent/utility/native_integer'

module Concurrent

  # @!macro atomic_fixnum
  # @!visibility private
  # @!macro internal_implementation_note
  class MutexAtomicFixnum < MutexAtomicInteger

    private

    # @!visibility private
    def ns_set(value)
      Utility::NativeInteger.ensure_integer_and_bounds value
      @value = value
    end
  end
end
