require 'concurrent/utility/native_extension_loader'

if defined?(Concurrent::JavaAtomicReference)
  require 'concurrent/atomic_reference/direct_update'

  module Concurrent

    # @!macro atomic_reference
    # @api private
    class JavaAtomicReference
      include Concurrent::AtomicDirectUpdate
    end
  end
end
