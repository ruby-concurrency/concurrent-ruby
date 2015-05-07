module Concurrent

  # An extension to Ruby's standard `ConditionVariable` which allows
  # waiting based on a condition.
  #
  # The condition variable in Ruby's standard library is susceptible
  # to spurious wakeups. It also does not provide any means to
  # determine if a wakeup is due to a timeout or to signaling. This
  # class addresses both those shortcomings. It provides two new
  # methods, `wait_until` and `wait_while` which each accpet a block.
  # The block operation is then used to determine the success or
  # failure (timeout) of the wait.
  #
  # @see http://ruby-doc.org/stdlib-2.0/libdoc/thread/rdoc/ConditionVariable.html Ruby ConditionVariable
  class ConditionVariable < ::ConditionVariable

    # Wait until signaled *and* the given condition is met or until
    # the optional timeout is reached.
    #
    # Releases the lock held in `mutex` and waits; reacquires the
    # lock on wakeup.
    #
    # If timeout is given, this method returns after timeout seconds
    # passed, even if no other thread doesn’t signal.
    #
    # @param [Mutex] mutex the mutex around which to lock and wait
    # @param [Float] timeout the maximum number of seconds to wait
    # @yield the condition which must be true before waking up
    # @return [Boolean] true if the condition is met or false on timeout
    #
    # @note The wait *must* be interrupted by a `#signal`,
    # `#broadcast`, timeout. The condition will be checked once when
    # the method is first called. It will not be checked again until
    # wakeup.
    #
    # @see http://ruby-doc.org/stdlib-2.0/libdoc/thread/rdoc/ConditionVariable.html#method-i-wait Ruby ConditionVariable
    def wait_until(mutex, timeout = nil)
      return true if yield
      if timeout.nil?
        wait(mutex) until yield
        true
      else
        stop = Concurrent.monotonic_time + timeout
        until (ok = yield) || timeout <= 0.0
          wait(mutex, timeout)
          timeout = stop - Concurrent.monotonic_time
        end
        ok || yield
      end
    end

    # Wait until signaled *and* the given condition ceases to hold
    # true or until the optional timeout is reached.
    #
    # Releases the lock held in `mutex` and waits; reacquires the
    # lock on wakeup.
    #
    # If timeout is given, this method returns after timeout seconds
    # passed, even if no other thread doesn’t signal.
    #
    # @param [Mutex] mutex the mutex around which to lock and wait
    # @param [Float] timeout the maximum number of seconds to wait
    # @yield the condition which will cause the wait to hold
    # @return [Boolean] true if worken up when the condition ceased
    #   to hold true or false on timeout
    #
    # @note The wait *must* be interrupted by a `#signal`,
    # `#broadcast`, timeout. The condition will be checked once when
    # the method is first called. It will not be checked again until
    # wakeup.
    #
    # @see http://ruby-doc.org/stdlib-2.0/libdoc/thread/rdoc/ConditionVariable.html#method-i-wait Ruby ConditionVariable
    def wait_while(mutex, timeout = nil)
      if timeout.nil?
        while yield
          wait(mutex)
        end
        true
      else
        stop = Concurrent.monotonic_time + timeout
        while (blocked = yield) && timeout > 0.0
          wait(mutex, timeout)
          timeout = stop - Concurrent.monotonic_time
        end
        !blocked || !yield
      end
    end
  end
end
