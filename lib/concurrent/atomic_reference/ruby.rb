begin
  require 'concurrent_cruby'
rescue LoadError
  # may be a Windows cross-compiled native gem
  require "#{RUBY_VERSION[0..2]}/concurrent_cruby"
end

require 'concurrent/atomic_reference/direct_update'
require 'concurrent/atomic_reference/numeric_cas_wrapper'

module Concurrent
  class CAtomic
    include Concurrent::AtomicDirectUpdate
    include Concurrent::AtomicNumericCompareAndSetWrapper
  end
end
