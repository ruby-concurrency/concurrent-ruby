if defined? Concurrent::CAtomic
  require_relative '../../extension_helper'
  require 'concurrent/atomic_reference/direct_update'
  require 'concurrent/atomic_reference/numeric_cas_wrapper'

  module Concurrent

    # @!macro atomic_reference
    class CAtomic
      include Concurrent::AtomicDirectUpdate
      include Concurrent::AtomicNumericCompareAndSetWrapper

      # @!method initialize
      #   @!macro atomic_reference_method_initialize

      # @!method get
      #   @!macro atomic_reference_method_get

      # @!method set
      #   @!macro atomic_reference_method_set

      # @!method get_and_set
      #   @!macro atomic_reference_method_get_and_set

      # @!method _compare_and_set
      #   @!macro atomic_reference_method_compare_and_set
    end
  end
end
