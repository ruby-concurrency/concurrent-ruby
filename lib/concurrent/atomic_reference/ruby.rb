require 'concurrent_cruby'
require 'concurrent/atomic_reference/direct_update'
require 'concurrent/atomic_reference/numeric_cas_wrapper'

module Concurrent
  class CAtomic
    include Concurrent::AtomicDirectUpdate
    include Concurrent::AtomicNumericCompareAndSetWrapper
  end
end
