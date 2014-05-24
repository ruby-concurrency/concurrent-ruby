require 'concurrent/errors'
require 'concurrent/atomic/event'

module Concurrent

  module Executor
    def can_overflow?
      false
    end
  end

  module RubyExecutor
    include Executor

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Array] args zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] `true` if the task is queued, `false` if the executor
    #   is not running
    #
    # @raise [ArgumentError] if no task is given
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      mutex.synchronize do
        return false unless running?
        execute(*args, &task)
        true
      end
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Proc] task the asynchronous task to perform
    #
    # @return [self] returns itself
    def <<(task)
      post(&task)
      self
    end

    # Is the executor running?
    #
    # @return [Boolean] `true` when running, `false` when shutting down or shutdown
    def running?
      ! stop_event.set?
    end

    # Is the executor shuttingdown?
    #
    # @return [Boolean] `true` when not running and not shutdown, else `false`
    def shuttingdown?
      ! (running? || shutdown?)
    end

    # Is the executor shutdown?
    #
    # @return [Boolean] `true` when shutdown, `false` when shutting down or running
    def shutdown?
      stopped_event.set?
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the
    # thread pool is not running.
    def shutdown
      mutex.synchronize do
        break unless running?
        stop_event.set
        shutdown_execution
      end
      true
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
      mutex.synchronize do
        break if shutdown?
        stop_event.set
        kill_execution
        stopped_event.set
      end
      true
    end

    # Block until executor shutdown is complete or until `timeout` seconds have
    # passed.
    #
    # @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
    #   must be called before this method (or on another thread).
    #
    # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean] `true` if shutdown complete or false on `timeout`
    def wait_for_termination(timeout = nil)
      stopped_event.wait(timeout)
    end

    protected

    attr_reader :mutex, :stop_event, :stopped_event

    def init_executor
      @mutex = Mutex.new
      @stop_event = Event.new
      @stopped_event = Event.new
    end

    def execute(*args, &task)
      raise NotImplementedError
    end

    def shutdown_execution
      stopped_event.set
    end

    def kill_execution
      # do nothing
    end
  end

  if RUBY_PLATFORM == 'java'

    module JavaExecutor
      include Executor

      # Submit a task to the executor for asynchronous processing.
      #
      # @param [Array] args zero or more arguments to be passed to the task
      #
      # @yield the asynchronous task to perform
      #
      # @return [Boolean] `true` if the task is queued, `false` if the executor
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

      # Submit a task to the executor for asynchronous processing.
      #
      # @param [Proc] task the asynchronous task to perform
      #
      # @return [self] returns itself
      def <<(task)
        post(&task)
        self
      end

      # Is the executor running?
      #
      # @return [Boolean] `true` when running, `false` when shutting down or shutdown
      def running?
        ! (shuttingdown? || shutdown?)
      end

      # Is the executor shuttingdown?
      #
      # @return [Boolean] `true` when not running and not shutdown, else `false`
      def shuttingdown?
        if @executor.respond_to? :isTerminating
          @executor.isTerminating
        else
          false
        end
      end

      # Is the executor shutdown?
      #
      # @return [Boolean] `true` when shutdown, `false` when shutting down or running
      def shutdown?
        @executor.isShutdown || @executor.isTerminated
      end

      # Block until executor shutdown is complete or until `timeout` seconds have
      # passed.
      #
      # @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
      #   must be called before this method (or on another thread).
      #
      # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
      #
      # @return [Boolean] `true` if shutdown complete or false on `timeout`
      def wait_for_termination(timeout)
        @executor.awaitTermination(1000 * timeout, java.util.concurrent.TimeUnit::MILLISECONDS)
      end

      # Begin an orderly shutdown. Tasks already in the queue will be executed,
      # but no new tasks will be accepted. Has no additional effect if the
      # executor is not running.
      def shutdown
        @executor.shutdown
        nil
      end

      # Begin an immediate shutdown. In-progress tasks will be allowed to
      # complete but enqueued tasks will be dismissed and no new tasks
      # will be accepted. Has no additional effect if the executor is
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
