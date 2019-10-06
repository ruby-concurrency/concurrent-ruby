module Concurrent

  # Used for wrapping an Executor with Wrapper which can modify arguments or task passed to Executor
  class WrappingExecutor < Synchronization::Object
    safe_initialization!

    include ExecutorService

    # @param [Executor] executor Executor to be wrapped
    # @yield [*args, &task] Wrapper block which wraps the task with args before it is passed to the Executor
    # @yieldparam [Array<Object>] *args Wrapper block will get these from {WrappingExecutor#post} call
    # @yieldparam [block] &task Wrapper block will get this from {WrappingExecutor#post} call
    # @yieldreturn [Array<Object>] args and task on the last place.
    def initialize(executor, &wrapper)
      super()
      @Wrapper  = wrapper
      @Executor = executor
    end

    def post(*args, &task)
      *args, task = @Wrapper.call(*args, &task)
      @Executor.post(*args, &task)
    end

    def can_overflow?
      @Executor.can_overflow?
    end

    def serialized?
      @Executor.serialized?
    end
  end
end
