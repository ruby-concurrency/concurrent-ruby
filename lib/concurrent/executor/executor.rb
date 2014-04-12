require 'concurrent/atomic/event'

module Concurrent

  # An exception class raised when the maximum queue size is reached and the
  # `overflow_policy` is set to `:abort`.
  RejectedExecutionError = Class.new(StandardError)

  module Executor

    # Is the thread pool running?
    #
    # @return [Boolean] `true` when running, `false` when shutting down or shutdown
    def running?
      ! @stop_event.set?
    end

    # Is the thread pool shutdown?
    #
    # @return [Boolean] `true` when shutdown, `false` when shutting down or running
    def shutdown?
      @stop_event.set?
    end

    def shutdown
    end

    def kill
    end

    # Block until thread pool shutdown is complete or until `timeout` seconds have
    # passed.
    #
    # @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
    #   must be called before this method (or on another thread).
    #
    # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean] `true` if shutdown complete or false on `timeout`
    def wait_for_termination(timeout)
      @stopped_event.wait(timeout.to_i)
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

    attr_reader :mutex, :stop_event, :stopped_event

    def init_executor
      @mutex = Mutex.new
      @stop_event = Event.new
      @stopped_event = Event.new
    end

    def execute(*args, &task)
    end
  end
end
