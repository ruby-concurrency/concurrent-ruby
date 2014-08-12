require_relative '../../extension_helper'

if Concurrent.allow_c_extensions?
  begin
    require 'concurrent_ruby_ext'
  rescue LoadError
    begin
      # may be a Windows cross-compiled native gem
      require "#{RUBY_VERSION[0..2]}/concurrent_ruby_ext"
    rescue LoadError
      warn 'Attempted to load C extensions on unsupported platform. Continuing with pure-Ruby.'
    end
  end
end

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
