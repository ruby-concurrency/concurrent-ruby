require 'concurrent/errors'
require 'concurrent/logging'
require 'concurrent/atomic/event'

module Concurrent

  module Executor
    # The policy defining how rejected tasks (tasks received once the
    # queue size reaches the configured `max_queue`, or after the
    # executor has shut down) are handled. Must be one of the values
    # specified in `FALLBACK_POLICIES`.
    attr_reader :fallback_policy

    # @!macro [attach] executor_module_method_can_overflow_question
    #
    #   Does the task queue have a maximum size?
    #
    #   @return [Boolean] True if the task queue has a maximum size else false.
    #
    # @note Always returns `false`
    def can_overflow?
      false
    end

    # Handler which executes the `fallback_policy` once the queue size
    # reaches `max_queue`.
    #
    # @param [Array] args the arguments to the task which is being handled.
    #
    # @!visibility private
    def handle_fallback(*args)
      case @fallback_policy
      when :abort
        raise RejectedExecutionError
      when :discard
        false
      when :caller_runs
        begin
          yield(*args)
        rescue => ex
          # let it fail
          log DEBUG, ex
        end
        true
      else
        fail "Unknown fallback policy #{@fallback_policy}"
      end
    end

    # @!macro [attach] executor_module_method_serialized_question
    #
    #   Does this executor guarantee serialization of its operations?
    #
    #   @return [Boolean] True if the executor guarantees that all operations
    #     will be post in the order they are received and no two operations may
    #     occur simultaneously. Else false.
    #
    # @note Always returns `false`
    def serialized?
      false
    end
  end

  # Indicates that the including `Executor` or `ExecutorService` guarantees
  # that all operations will occur in the order they are post and that no
  # two operations may occur simultaneously. This module provides no
  # functionality and provides no guarantees. That is the responsibility
  # of the including class. This module exists solely to allow the including
  # object to be interrogated for its serialization status.
  #
  # @example
  #   class Foo
  #     include Concurrent::SerialExecutor
  #   end
  #
  #   foo = Foo.new
  #
  #   foo.is_a? Concurrent::Executor       #=> true
  #   foo.is_a? Concurrent::SerialExecutor #=> true
  #   foo.serialized?                      #=> true
  module SerialExecutor
    include Executor

    # @!macro executor_module_method_serialized_question
    #
    # @note Always returns `true`
    def serialized?
      true
    end
  end

  module RubyExecutor
    include Executor
    include Logging

    # The set of possible fallback policies that may be set at thread pool creation.
    FALLBACK_POLICIES          = [:abort, :discard, :caller_runs]

    # @!macro [attach] executor_method_post
    #
    #   Submit a task to the executor for asynchronous processing.
    #
    #   @param [Array] args zero or more arguments to be passed to the task
    #
    #   @yield the asynchronous task to perform
    #
    #   @return [Boolean] `true` if the task is queued, `false` if the executor
    #     is not running
    #
    #   @raise [ArgumentError] if no task is given
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      mutex.synchronize do
        # If the executor is shut down, reject this task
        return handle_fallback(*args, &task) unless running?
        execute(*args, &task)
        true
      end
    end

    # @!macro [attach] executor_method_left_shift
    #
    #   Submit a task to the executor for asynchronous processing.
    #
    #   @param [Proc] task the asynchronous task to perform
    #
    #   @return [self] returns itself
    def <<(task)
      post(&task)
      self
    end

    # @!macro [attach] executor_method_running_question
    #
    #   Is the executor running?
    #
    #   @return [Boolean] `true` when running, `false` when shutting down or shutdown
    def running?
      ! stop_event.set?
    end

    # @!macro [attach] executor_method_shuttingdown_question
    #
    #   Is the executor shuttingdown?
    #
    #   @return [Boolean] `true` when not running and not shutdown, else `false`
    def shuttingdown?
      ! (running? || shutdown?)
    end

    # @!macro [attach] executor_method_shutdown_question
    #
    #   Is the executor shutdown?
    #
    #   @return [Boolean] `true` when shutdown, `false` when shutting down or running
    def shutdown?
      stopped_event.set?
    end

    # @!macro [attach] executor_method_shutdown
    #
    #   Begin an orderly shutdown. Tasks already in the queue will be executed,
    #   but no new tasks will be accepted. Has no additional effect if the
    #   thread pool is not running.
    def shutdown
      mutex.synchronize do
        break unless running?
        stop_event.set
        shutdown_execution
      end
      true
    end

    # @!macro [attach] executor_method_kill
    #
    #   Begin an immediate shutdown. In-progress tasks will be allowed to
    #   complete but enqueued tasks will be dismissed and no new tasks
    #   will be accepted. Has no additional effect if the thread pool is
    #   not running.
    def kill
      mutex.synchronize do
        break if shutdown?
        stop_event.set
        kill_execution
        stopped_event.set
      end
      true
    end

    # @!macro [attach] executor_method_wait_for_termination
    #
    #   Block until executor shutdown is complete or until `timeout` seconds have
    #   passed.
    #
    #   @note Does not initiate shutdown or termination. Either `shutdown` or `kill`
    #     must be called before this method (or on another thread).
    #
    #   @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    #   @return [Boolean] `true` if shutdown complete or false on `timeout`
    def wait_for_termination(timeout = nil)
      stopped_event.wait(timeout)
    end

    protected

    attr_reader :mutex, :stop_event, :stopped_event

    # @!macro [attach] executor_method_init_executor
    #
    #   Initialize the executor by creating and initializing all the
    #   internal synchronization objects.
    def init_executor
      @mutex = Mutex.new
      @stop_event = Event.new
      @stopped_event = Event.new
    end

    # @!macro [attach] executor_method_execute
    def execute(*args, &task)
      raise NotImplementedError
    end

    # @!macro [attach] executor_method_shutdown_execution
    # 
    #   Callback method called when an orderly shutdown has completed.
    #   The default behavior is to signal all waiting threads.
    def shutdown_execution
      stopped_event.set
    end

    # @!macro [attach] executor_method_kill_execution
    #
    #   Callback method called when the executor has been killed.
    #   The default behavior is to do nothing.
    def kill_execution
      # do nothing
    end
  end

  if RUBY_PLATFORM == 'java'

    module JavaExecutor
      include Executor
      java_import 'java.lang.Runnable'

      # The set of possible fallback policies that may be set at thread pool creation.
      FALLBACK_POLICIES = {
        abort: java.util.concurrent.ThreadPoolExecutor::AbortPolicy,
        discard: java.util.concurrent.ThreadPoolExecutor::DiscardPolicy,
        caller_runs: java.util.concurrent.ThreadPoolExecutor::CallerRunsPolicy
      }.freeze

      # @!macro executor_method_post
      def post(*args, &task)
        raise ArgumentError.new('no block given') unless block_given?
        return handle_fallback(*args, &task) unless running?
        executor_submit = @executor.java_method(:submit, [Runnable.java_class])
        executor_submit.call { yield(*args) }
        true
      rescue Java::JavaUtilConcurrent::RejectedExecutionException
        raise RejectedExecutionError
      end

      # @!macro executor_method_left_shift
      def <<(task)
        post(&task)
        self
      end

      # @!macro executor_method_running_question
      def running?
        ! (shuttingdown? || shutdown?)
      end

      # @!macro executor_method_shuttingdown_question
      def shuttingdown?
        if @executor.respond_to? :isTerminating
          @executor.isTerminating
        else
          false
        end
      end

      # @!macro executor_method_shutdown_question
      def shutdown?
        @executor.isShutdown || @executor.isTerminated
      end

      # @!macro executor_method_wait_for_termination
      def wait_for_termination(timeout = nil)
        if timeout.nil?
          ok = @executor.awaitTermination(60, java.util.concurrent.TimeUnit::SECONDS) until ok
          true
        else
          @executor.awaitTermination(1000 * timeout, java.util.concurrent.TimeUnit::MILLISECONDS)
        end
      end

      # @!macro executor_method_shutdown
      def shutdown
        @executor.shutdown
        nil
      end

      # @!macro executor_method_kill
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
