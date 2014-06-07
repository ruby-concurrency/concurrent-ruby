require 'concurrent_jruby'
require 'concurrent/atomic_reference/direct_update'

module Concurrent
  class JavaAtomic
    include Concurrent::AtomicDirectUpdate
  end
end
