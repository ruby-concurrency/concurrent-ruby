module Concurrent

  # extend Rubinius's version adding aliases and numeric logic
  class Atomic < Rubinius::AtomicReference
    alias value get
    alias value= set
    alias swap get_and_set
  end

  require 'concurrent/atomic_reference/direct_update'
  require 'concurrent/atomic_reference/numeric_cas_wrapper'
end
