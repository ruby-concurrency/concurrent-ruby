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

  if RUBY_PLATFORM == 'java'

    module JavaExecutor

      # Submit a task to the thread pool for asynchronous processing.
      #
      # @param [Array] args zero or more arguments to be passed to the task
      #
      # @yield the asynchronous task to perform
      #
      # @return [Boolean] `true` if the task is queued, `false` if the thread pool
      #   is not running
      #
      # @raise [ArgumentError] if no task is given
      def post(*args)
        raise ArgumentError.new('no block given') unless block_given?
        if running?
          @executor.submit{ yield(*args) }
          true
        else
          false
        end
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        raise RejectedExecutionError
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

      # Is the thread pool running?
      #
      # @return [Boolean] `true` when running, `false` when shutting down or shutdown
      def running?
        ! (@executor.isShutdown || @executor.isTerminated)
      end

      # Is the thread pool shutdown?
      #
      # @return [Boolean] `true` when shutdown, `false` when shutting down or running
      def shutdown?
        @executor.isShutdown
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
        @executor.awaitTermination(timeout.to_i, java.util.concurrent.TimeUnit::SECONDS)
      end

      # Begin an orderly shutdown. Tasks already in the queue will be executed,
      # but no new tasks will be accepted. Has no additional effect if the
      # thread pool is not running.
      def shutdown
        @executor.shutdown
        return nil
      end

      # Begin an immediate shutdown. In-progress tasks will be allowed to
      # complete but enqueued tasks will be dismissed and no new tasks
      # will be accepted. Has no additional effect if the thread pool is
      # not running.
      def kill
        @executor.shutdownNow
        nil
      end

      protected

      def set_shutdown_hook
        # without this the process may fail to exit
        at_exit { self.kill }
      end
    end
  end
end
