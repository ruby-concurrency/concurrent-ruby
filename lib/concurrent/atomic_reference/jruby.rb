require 'concurrent/native_extensions'

if defined?(Concurrent::JavaAtomicReference)
  require 'concurrent/atomic_reference/direct_update'

  module Concurrent

    # @!macro atomic_reference
    class JavaAtomicReference
      include Concurrent::AtomicDirectUpdate
    end
  end
end
