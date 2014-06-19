require 'concurrent/atomic_reference/concurrent_update_error'
require 'concurrent/atomic_reference/mutex_atomic'

begin
  # force fallback impl with FORCE_ATOMIC_FALLBACK=1
  if /[^0fF]/ =~ ENV['FORCE_ATOMIC_FALLBACK']
    ruby_engine = 'mutex_atomic'
  else
    ruby_engine = defined?(RUBY_ENGINE)? RUBY_ENGINE : 'ruby'
  end

  require "concurrent/atomic_reference/#{ruby_engine}"
rescue LoadError
  warn 'Compiled extensions not installed, pure Ruby Atomic will be used.'
end

if defined? Concurrent::JavaAtomic

  # @!macro [attach] atomic_reference
  #
  #   An object reference that may be updated atomically.
  #
  #   @since 0.7.0.rc0
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/AtomicReference.html
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/package-summary.html
  class Concurrent::Atomic < Concurrent::JavaAtomic
  end

elsif defined? Concurrent::CAtomic

  # @!macro [attach] concurrent_update_error
  #
  # This exception may be thrown by methods that have detected concurrent
  # modification of an object when such modification is not permissible.
  class Concurrent::Atomic < Concurrent::CAtomic
  end

elsif defined? Concurrent::RbxAtomic

  # @!macro atomic_reference
  class Concurrent::Atomic < Concurrent::RbxAtomic
  end

else

  # @!macro atomic_reference
  class Concurrent::Atomic < Concurrent::MutexAtomic
  end
end

# @!macro atomic_reference
class Atomic < Concurrent::Atomic

  # @!macro concurrent_update_error
  ConcurrentUpdateError = Class.new(Concurrent::ConcurrentUpdateError)

  # @!macro [attach] atomic_reference_method_initialize
  #
  # Creates a new Atomic reference with null initial value.
  #
  # @param [Object] value the initial value
  def initialize(value)
    warn "[DEPRECATED] Please use Concurrent::Atomic instead."
    super
  end
end
