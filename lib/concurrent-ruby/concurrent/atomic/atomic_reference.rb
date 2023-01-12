require 'concurrent/utility/native_extension_loader' # load native parts first

require 'concurrent/atomic_reference/atomic_direct_update'
require 'concurrent/atomic_reference/numeric_cas_wrapper'
require 'concurrent/atomic_reference/mutex_atomic'

# Shim for TruffleRuby::AtomicReference
if Concurrent.on_truffleruby? && !defined?(TruffleRuby::AtomicReference)
  # @!visibility private
  module TruffleRuby
    AtomicReference = Truffle::AtomicReference
  end
end

module Concurrent

  # @!macro atomic_reference
  #
  #   An object reference that may be updated atomically. All read and write
  #   operations have java volatile semantic.
  #
  #   @!macro thread_safe_variable_comparison
  #
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/AtomicReference.html
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/package-summary.html
  #
  #   @!method initialize(value = nil)
  #     @!macro atomic_reference_method_initialize
  #       @param [Object] value The initial value.
  #
  #   @!method get
  #     @!macro atomic_reference_method_get
  #       Gets the current value.
  #       @return [Object] the current value
  #
  #   @!method set(new_value)
  #     @!macro atomic_reference_method_set
  #       Sets to the given value.
  #       @param [Object] new_value the new value
  #       @return [Object] the new value
  #
  #   @!method get_and_set(new_value)
  #     @!macro atomic_reference_method_get_and_set
  #       Atomically sets to the given value and returns the old value.
  #       @param [Object] new_value the new value
  #       @return [Object] the old value
  #
  #   @!method compare_and_set(old_value, new_value)
  #     @!macro atomic_reference_method_compare_and_set
  #
  #       Atomically sets the value to the given updated value if
  #       the current value == the expected value.
  #
  #       @param [Object] old_value the expected value
  #       @param [Object] new_value the new value
  #
  #       @return [Boolean] `true` if successful. A `false` return indicates
  #       that the actual value was not equal to the expected value.
  #
  #   @!method update
  #     @!macro atomic_reference_method_update
  #
  #   @!method try_update
  #     @!macro atomic_reference_method_try_update
  #
  #   @!method try_update!
  #     @!macro atomic_reference_method_try_update!

  # @!macro internal_implementation_note
  AtomicReferenceImplementation = case
                                  when Concurrent.on_cruby? && Concurrent.c_extensions_loaded?
                                    # @!visibility private
                                    # @!macro internal_implementation_note
                                    class CAtomicReference
                                      include AtomicDirectUpdate
                                      include AtomicNumericCompareAndSetWrapper
                                      alias_method :compare_and_swap, :compare_and_set
                                    end
                                    CAtomicReference
                                  when Concurrent.on_jruby?
                                    # @!visibility private
                                    # @!macro internal_implementation_note
                                    class JavaAtomicReference
                                      include AtomicDirectUpdate
                                    end
                                    JavaAtomicReference
                                  when Concurrent.on_truffleruby?
                                    class TruffleRubyAtomicReference < TruffleRuby::AtomicReference
                                      include AtomicDirectUpdate
                                      alias_method :value, :get
                                      alias_method :value=, :set
                                      alias_method :compare_and_swap, :compare_and_set
                                      alias_method :swap, :get_and_set
                                    end
                                    TruffleRubyAtomicReference
                                  else
                                    MutexAtomicReference
                                  end
  private_constant :AtomicReferenceImplementation

  # @!macro atomic_reference
  class AtomicReference < AtomicReferenceImplementation

    # @return [String] Short string representation.
    def to_s
      format '%s value:%s>', super[0..-2], get
    end

    alias_method :inspect, :to_s
  end
end
