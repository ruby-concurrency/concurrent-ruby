module Concurrent

  # @!visibility private
  module ThreadSafe

    # @!visibility private
    module Util

      FIXNUM_BIT_SIZE = (0.size * 8) - 2
      MAX_INT         = (2 ** FIXNUM_BIT_SIZE) - 1
      CPU_COUNT       = 16 # is there a way to determine this?

      autoload :Tuple,           'concurrent/tuple'
      autoload :Adder,           'concurrent/thread_safe/util/adder'
      autoload :CheapLockable,   'concurrent/thread_safe/util/cheap_lockable'
      autoload :PowerOfTwoTuple, 'concurrent/thread_safe/util/power_of_two_tuple'
      autoload :Volatile,        'concurrent/thread_safe/util/volatile'
      autoload :Striped64,       'concurrent/thread_safe/util/striped64'
      autoload :XorShiftRandom,  'concurrent/thread_safe/util/xor_shift_random'
    end
  end
end
