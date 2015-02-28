require 'thread'
require 'concurrent/configuration'
require 'concurrent/obligation'
require 'concurrent/executor/executor_options'

module Concurrent

  # Lazy evaluation of a block yielding an immutable result. Useful for
  # expensive operations that may never be needed. `Delay` is a more
  # complex and feature-rich version of `Lazy`. It is non-blocking,
  # supports the `Obligation` interface, and accepts the injection of
  # custom executor upon which to execute the block. Processing of
  # block will be deferred until the first time `#value` is called.
  # At that time the caller can choose to return immediately and let
  # the block execute asynchronously, block indefinitely, or block
  # with a timeout.
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
  # Because of its simplicity `Lazy` is much faster than `Delay`:
  #
  #            user     system      total        real
  #     Benchmarking Delay...
  #        0.730000   0.000000   0.730000 (  0.738434)
  #     Benchmarking Lazy...
  #        0.040000   0.000000   0.040000 (  0.042322)
  #
  # @see Concurrent::Dereferenceable
  # @see Concurrent::Lazy
  class Delay
    include Obligation
    include ExecutorOptions

    # Create a new `Delay` in the `:pending` state.
    #
    # @yield the delayed operation to perform
    #
    # @!macro [attach] executor_and_deref_options
    #  
    #   @param [Hash] opts the options used to define the behavior at update and deref
    #     and to specify the executor on which to perform actions
    #   @option opts [Executor] :executor when set use the given `Executor` instance.
    #     Three special values are also supported: `:task` returns the global task pool,
    #     `:operation` returns the global operation pool, and `:immediate` returns a new
    #     `ImmediateExecutor` object.
    #   @option opts [Boolean] :dup_on_deref (false) call `#dup` before returning the data
    #   @option opts [Boolean] :freeze_on_deref (false) call `#freeze` before returning the data
    #   @option opts [Proc] :copy_on_deref (nil) call the given `Proc` passing
    #     the internal value and returning the value returned from the proc
    #
    # @raise [ArgumentError] if no block is given
    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      init_obligation
      @state = :pending
      @task  = block
      set_deref_options(opts)
      @task_executor = get_executor_from(opts) || Concurrent.global_io_executor
      @computing     = false
    end

    # Return the value this object represents after applying the options
    # specified by the `#set_deref_options` method.
    #
    # @param [Integer] timeout (nil) the maximum number of seconds to wait for
    #   the value to be computed. When `nil` the caller will block indefinitely.
    #
    # @return [Object] the current value of the object
    def wait(timeout = nil)
      execute_task_once
      super(timeout)
    end

    # Reconfigures the block returning the value if still `#incomplete?`
    #
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

    # @!visibility private
    def execute_task_once # :nodoc:
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
