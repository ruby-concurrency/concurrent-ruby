module Concurrent

  # An exception class raised when the maximum queue size is reached and the
  # `overflow_policy` is set to `:abort`.
  RejectedExecutionError = Class.new(StandardError)

  module Executor

    def running?
      true
    end

    def shutdown?
      false
    end

    def shutdown
    end

    def kill
    end

    def wait_for_termination(timeout)
    end

    def post(*args, &task)
    end

    # Submit a task to the thread pool for asynchronous processing.
    #
    # @param [Proc] task the asynchronous task to perform
    #
    # @return [self] returns itself
    def <<(task)
      post(&task)
      self
    end

    protected

    def init_executor
    end

    def execute(*args, &task)
    end
  end
end
