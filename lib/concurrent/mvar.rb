require 'concurrent/dereferenceable'

module Concurrent

  # An `MVar` is a synchronized single element container. They are empty or
  # contain one item. Taking a value from an empty `MVar` blocks, as does
  # putting a value into a full one. You can either think of them as blocking
  # queue of length one, or a special kind of mutable variable.
  #
  # On top of the fundamental `#put` and `#take` operations, we also provide a
  # `#mutate` that is atomic with respect to operations on the same instance.
  # These operations all support timeouts.
  #
  # We also support non-blocking operations `#try_put!` and `#try_take!`, a
  # `#set!` that ignores existing values, a `#value` that returns the value
  # without removing it or returns `MVar::EMPTY`, and a `#modify!` that yields
  # `MVar::EMPTY` if the `MVar` is empty and can be used to set `MVar::EMPTY`.
  # You shouldn't use these operations in the first instance.
  #
  # `MVar` is a [Dereferenceable](Dereferenceable).
  #
  # `MVar` is related to M-structures in Id, `MVar` in Haskell and `SyncVar` in Scala.
  #
  # Note that unlike the original Haskell paper, our `#take` is blocking. This is how
  # Haskell and Scala do it today.
  #
  # **See Also:**
  #
  # 1. P. Barth, R. Nikhil, and Arvind. [M-Structures: Extending a parallel, non- strict, functional language with state](http://dl.acm.org/citation.cfm?id=652538). In Proceedings of the 5th
  # ACM Conference on Functional Programming Languages and Computer Architecture (FPCA), 1991.
  # 2. S. Peyton Jones, A. Gordon, and S. Finne. [Concurrent Haskell](http://dl.acm.org/citation.cfm?id=237794).
  # In Proceedings of the 23rd Symposium on Principles of Programming Languages
  # (PoPL), 1996.
  class MVar

    include Dereferenceable

    # Unique value that represents that an `MVar` was empty
    EMPTY = Object.new

    # Unique value that represents that an `MVar` timed out before it was able
    # to produce a value.
    TIMEOUT = Object.new

    # Create a new `MVar`, either empty or with an initial value.
    #
    # @param [Hash] opts the options controlling how the future will be processed
    # @option opts [Boolean] :operation (false) when `true` will execute the
    #   future on the global operation pool (for long-running operations), when
    #   `false` will execute the future on the global task pool (for
    #   short-running tasks)
    # @option opts [object] :executor when provided will run all operations on
    #   this executor rather than the global thread pool (overrides :operation)
    # @option opts [String] :dup_on_deref (false) call `#dup` before returning the data
    # @option opts [String] :freeze_on_deref (false) call `#freeze` before
    #   returning the data
    # @option opts [String] :copy_on_deref (nil) call the given `Proc` passing
    #   the internal value and returning the value returned from the proc
    def initialize(value = EMPTY, opts = {})
      @value = value
      @mutex = Mutex.new
      @empty_condition = ConditionVariable.new
      @full_condition = ConditionVariable.new
      set_deref_options(opts)
    end

    # Remove the value from an `MVar`, leaving it empty, and blocking if there
    # isn't a value. A timeout can be set to limit the time spent blocked, in
    # which case it returns `TIMEOUT` if the time is exceeded.
    # @return [Object] the value that was taken, or `TIMEOUT`
    def take(timeout = nil)
      @mutex.synchronize do
        wait_for_full(timeout)

        # If we timed out we'll still be empty
        if unlocked_full?
          value = @value
          @value = EMPTY
          @empty_condition.signal
          apply_deref_options(value)
        else
          TIMEOUT
        end
      end
    end

    # Put a value into an `MVar`, blocking if there is already a value until
    # it is empty. A timeout can be set to limit the time spent blocked, in
    # which case it returns `TIMEOUT` if the time is exceeded.
    # @return [Object] the value that was put, or `TIMEOUT`
    def put(value, timeout = nil)
      @mutex.synchronize do
        wait_for_empty(timeout)

        # If we timed out we won't be empty
        if unlocked_empty?
          @value = value
          @full_condition.signal
          apply_deref_options(value)
        else
          TIMEOUT
        end
      end
    end

    # Atomically `take`, yield the value to a block for transformation, and then
    # `put` the transformed value. Returns the transformed value. A timeout can
    # be set to limit the time spent blocked, in which case it returns `TIMEOUT`
    # if the time is exceeded.
    # @return [Object] the transformed value, or `TIMEOUT`
    def modify(timeout = nil)
      raise ArgumentError.new('no block given') unless block_given?

      @mutex.synchronize do
        wait_for_full(timeout)

        # If we timed out we'll still be empty
        if unlocked_full?
          value = @value
          @value = yield value
          @full_condition.signal
          apply_deref_options(value)
        else
          TIMEOUT
        end
      end
    end

    # Non-blocking version of `take`, that returns `EMPTY` instead of blocking.
    def try_take!
      @mutex.synchronize do
        if unlocked_full?
          value = @value
          @value = EMPTY
          @empty_condition.signal
          apply_deref_options(value)
        else
          EMPTY
        end
      end
    end

    # Non-blocking version of `put`, that returns whether or not it was successful.
    def try_put!(value)
      @mutex.synchronize do
        if unlocked_empty?
          @value = value
          @full_condition.signal
          true
        else
          false
        end
      end
    end

    # Non-blocking version of `put` that will overwrite an existing value.
    def set!(value)
      @mutex.synchronize do
        old_value = @value
        @value = value
        @full_condition.signal
        apply_deref_options(old_value)
      end
    end

    # Non-blocking version of `modify` that will yield with `EMPTY` if there is no value yet.
    def modify!
      raise ArgumentError.new('no block given') unless block_given?

      @mutex.synchronize do
        value = @value
        @value = yield value
        if unlocked_empty?
          @empty_condition.signal
        else
          @full_condition.signal
        end
        apply_deref_options(value)
      end
    end

    # Returns if the `MVar` is currently empty.
    def empty?
      @mutex.synchronize { @value == EMPTY }
    end

    # Returns if the `MVar` currently contains a value.
    def full?
      !empty?
    end

    private

    def unlocked_empty?
      @value == EMPTY
    end

    def unlocked_full?
      ! unlocked_empty?
    end

    def wait_for_full(timeout)
      wait_while(@full_condition, timeout) { unlocked_empty? }
    end

    def wait_for_empty(timeout)
      wait_while(@empty_condition, timeout) { unlocked_full? }
    end

    def wait_while(condition, timeout)
      if timeout.nil?
        while yield
          condition.wait(@mutex)
        end
      else
        stop = Concurrent.monotonic_time + timeout
        while yield && timeout > 0.0
          condition.wait(@mutex, timeout)
          timeout = stop - Concurrent.monotonic_time
        end
      end
    end
  end
end
