require 'concurrent/atomic_reference/direct_update'
require 'concurrent/atomic_reference/numeric_cas_wrapper'

module Concurrent

  # extend Rubinius's version adding aliases and numeric logic
  class RbxAtomic < Rubinius::AtomicReference
    alias _compare_and_set compare_and_set
    include Concurrent::AtomicDirectUpdate
    include Concurrent::AtomicNumericCompareAndSetWrapper

    alias value get
    alias value= set
    alias swap get_and_set
  end
end
