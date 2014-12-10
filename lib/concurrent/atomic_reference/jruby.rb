require_relative '../../extension_helper'

if defined?(Concurrent::JavaAtomic)
  require 'concurrent/atomic_reference/direct_update'

  module Concurrent

    # @!macro atomic_reference
    class JavaAtomic
      include Concurrent::AtomicDirectUpdate
    end
  end
end
