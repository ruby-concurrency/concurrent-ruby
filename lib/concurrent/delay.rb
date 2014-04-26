require 'thread'

module Concurrent

  # Lazy evaluation of a block yielding an immutable result. Useful for expensive
  # operations that may never be needed.
  #
  # A `Delay` is similar to `Future` but solves a different problem.
  # Where a `Future` schedules an operation for immediate execution and
  # performs the operation asynchronously, a `Delay` (as the name implies)
  # delays execution of the operation until the result is actually needed.
  # 
  # When a `Delay` is created its state is set to `pending`. The value and
  # reason are both `nil`. The first time the `#value` method is called the
  # enclosed opration will be run and the calling thread will block. Other
  # threads attempting to call `#value` will block as well. Once the operation
  # is complete the *value* will be set to the result of the operation or the
  # *reason* will be set to the raised exception, as appropriate. All threads
  # blocked on `#value` will return. Subsequent calls to `#value` will immediately
  # return the cached value. The operation will only be run once. This means that
  # any side effects created by the operation will only happen once as well.
  #
  # `Delay` includes the `Concurrent::Dereferenceable` mixin to support thread
  # safety of the reference returned by `#value`.
  #
  # @since 0.6.0
  #
  # @see Concurrent::Dereferenceable
  #
  # @see http://clojuredocs.org/clojure_core/clojure.core/delay
  # @see http://aphyr.com/posts/306-clojure-from-the-ground-up-state
  class Delay
    include Obligation

    # Create a new `Delay` in the `:pending` state.
    #
    # @yield the delayed operation to perform
    #
    # @param [Hash] opts the options to create a message with
    # @option opts [String] :dup_on_deref (false) call `#dup` before returning the data
    # @option opts [String] :freeze_on_deref (false) call `#freeze` before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given `Proc` passing the internal value and
    #   returning the value returned from the proc
    #
    # @raise [ArgumentError] if no block is given
    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      init_obligation
      @state = :pending
      @task = block
      set_deref_options(opts)
    end

    # Return the (possibly memoized) value of the delayed operation.
    # 
    # If the state is `:pending` then the calling thread will block while the
    # operation is performed. All other threads simultaneously calling `#value`
    # will block as well. Once the operation is complete (either `:fulfilled` or
    # `:rejected`) all waiting threads will unblock and the new value will be
    # returned.
    #
    # If the state is not `:pending` when `#value` is called the (possibly memoized)
    # value will be returned without blocking and without performing the operation
    # again.
    #
    # Regardless of the final disposition all `Dereferenceable` options set during
    # object construction will be honored.
    #
    # @return [Object] the (possibly memoized) result of the block operation
    #
    # @see Concurrent::Dereferenceable
    def value
      mutex.lock
      execute_task_once
      result = apply_deref_options(@value)
      mutex.unlock

      result
    end

    private

      def execute_task_once
        if @state == :pending
          begin
            @value = @task.call
            @state = :fulfilled
          rescue => ex
            @reason = ex
            @state = :rejected
          end
        end
      end
  end
end
