#####################################################################
# Attempt to check for the deprecated ruby-atomic gem and warn the
# user that they should use the new implementation instead.

if defined?(Atomic)
  warn <<-RUBY
[ATOMIC] Detected an `Atomic` class, which may indicate a dependency
on the ruby-atomic gem. That gem has been deprecated and merged into
the concurrent-ruby gem. Please use the Concurrent::Atomic class for
atomic references and not the Atomic class.
RUBY
end
#####################################################################

require_relative '../extension_helper'
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
  #warn 'Compiled extensions not installed, pure Ruby Atomic will be used.'
end

if defined? Concurrent::JavaAtomic

  # @!macro [attach] atomic_reference
  #
  #   An object reference that may be updated atomically.
  #
  #       Testing with ruby 2.1.2
  #       
  #       *** Sequential updates ***
  #                        user     system      total        real
  #       no lock      0.000000   0.000000   0.000000 (  0.005502)
  #       mutex        0.030000   0.000000   0.030000 (  0.025158)
  #       MutexAtomic  0.100000   0.000000   0.100000 (  0.103096)
  #       CAtomic      0.040000   0.000000   0.040000 (  0.034012)
  #       
  #       *** Parallel updates ***
  #                        user     system      total        real
  #       no lock      0.010000   0.000000   0.010000 (  0.009387)
  #       mutex        0.030000   0.010000   0.040000 (  0.032545)
  #       MutexAtomic  0.830000   2.280000   3.110000 (  2.146622)
  #       CAtomic      0.040000   0.000000   0.040000 (  0.038332)
  #
  #       Testing with jruby 1.9.3
  #       
  #       *** Sequential updates ***
  #                        user     system      total        real
  #       no lock      0.170000   0.000000   0.170000 (  0.051000)
  #       mutex        0.370000   0.010000   0.380000 (  0.121000)
  #       MutexAtomic  1.530000   0.020000   1.550000 (  0.471000)
  #       JavaAtomic   0.370000   0.010000   0.380000 (  0.112000)
  #       
  #       *** Parallel updates ***
  #                        user     system      total        real
  #       no lock      0.390000   0.000000   0.390000 (  0.105000)
  #       mutex        0.480000   0.040000   0.520000 (  0.145000)
  #       MutexAtomic  1.600000   0.180000   1.780000 (  0.511000)
  #       JavaAtomic   0.460000   0.010000   0.470000 (  0.131000)
  #
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/AtomicReference.html
  #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/package-summary.html
  class Concurrent::Atomic < Concurrent::JavaAtomic
  end

elsif defined? Concurrent::RbxAtomic

  # @!macro atomic_reference
  class Concurrent::Atomic < Concurrent::RbxAtomic
  end

elsif defined? Concurrent::CAtomic

  # @!macro atomic_reference
  class Concurrent::Atomic < Concurrent::CAtomic
  end

else

  # @!macro atomic_reference
  class Concurrent::Atomic < Concurrent::MutexAtomic
  end
end
