module Concurrent

  # @!visibility private
  module ThreadSafe

    # @!visibility private
    module Util

      FIXNUM_BIT_SIZE = (0.size * 8) - 2
      MAX_INT         = (2 ** FIXNUM_BIT_SIZE) - 1
      CPU_COUNT       = 16 # is there a way to determine this?
    end
  end
end

require 'concurrent/tuple'
require 'concurrent/thread_safe/util/volatile'
require 'concurrent/thread_safe/util/striped64'
require 'concurrent/thread_safe/util/adder'
require 'concurrent/thread_safe/util/cheap_lockable'
require 'concurrent/thread_safe/util/power_of_two_tuple'

