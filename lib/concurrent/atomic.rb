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
  warn "#{__FILE__}:#{__LINE__}: unsupported Ruby engine `#{RUBY_ENGINE}', using less-efficient Atomic impl"
end

if defined? Concurrent::JavaAtomic

  class Concurrent::Atomic < Concurrent::JavaAtomic
  end

elsif defined? Concurrent::CAtomic

  class Concurrent::Atomic < Concurrent::CAtomic
  end

elsif defined? Concurrent::RbxAtomic

  class Concurrent::Atomic < Concurrent::RbxAtomic
  end

else

  class Concurrent::Atomic < Concurrent::MutexAtomic
  end
end

class Atomic < Concurrent::Atomic

  ConcurrentUpdateError = Class.new(Concurrent::ConcurrentUpdateError)

  def initialize(*args)
    warn "[DEPRECATED] Please use Concurrent::Atomic instead."
    super
  end
end
