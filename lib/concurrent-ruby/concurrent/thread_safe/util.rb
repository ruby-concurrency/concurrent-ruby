require 'rbconfig/sizeof'

module Concurrent

  # @!visibility private
  module ThreadSafe

    # @!visibility private
    module Util

      # TODO (pitr-ch 15-Oct-2016): migrate to Utility::NativeInteger
      # Use the pointer width, not Integer#size (the C `long` width), since
      # the two diverge on LLP64 platforms (64-bit Windows) - see #1057.
      FIXNUM_BIT_SIZE = (RbConfig::SIZEOF['void*'] * 8) - 2
      MAX_INT         = (2 ** FIXNUM_BIT_SIZE) - 1
      # TODO (pitr-ch 15-Oct-2016): migrate to Utility::ProcessorCounter
      CPU_COUNT       = 16 # is there a way to determine this?
    end
  end
end
