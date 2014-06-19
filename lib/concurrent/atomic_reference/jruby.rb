require 'concurrent_ruby_ext'
require 'concurrent/atomic_reference/direct_update'

module Concurrent

  # @!macro atomic_reference
  class JavaAtomic
    include Concurrent::AtomicDirectUpdate
  end
end
