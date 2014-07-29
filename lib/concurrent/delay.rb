require 'thread'
require 'concurrent/obligation'
require 'concurrent/options_parser'

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
      @task  = block
      set_deref_options(opts)
      @task_executor = OptionsParser.get_task_executor_from(opts)
      @computing     = false
    end

    def wait(timeout)
      execute_task_once
      super timeout
    end

    # reconfigures the block returning the value if still #incomplete?
    # @yield the delayed operation to perform
    # @return [true, false] if success
    def reconfigure(&block)
      mutex.lock
      raise ArgumentError.new('no block given') unless block_given?
      unless @computing
        @task = block
        true
      else
        false
      end
    ensure
      mutex.unlock
    end

    private

    def execute_task_once
      mutex.lock
      execute = @computing = true unless @computing
      task    = @task
      mutex.unlock

      if execute
        @task_executor.post do
          begin
            result  = task.call
            success = true
          rescue => ex
            reason = ex
          end
          mutex.lock
          set_state success, result, reason
          event.set
          mutex.unlock
        end
      end
    end
  end
end
