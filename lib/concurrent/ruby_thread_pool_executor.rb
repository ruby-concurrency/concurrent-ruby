module Concurrent

  # @!macro thread_pool_executor
  class RubyThreadPoolExecutor

    # The maximum number of threads that will be created in the pool
    # (unless overridden during construction).
    DEFAULT_MAX_POOL_SIZE = 2**15 # 32768

    # The minimum number of threads that will be created in the pool
    # (unless overridden during construction).
    DEFAULT_MIN_POOL_SIZE = 0

    DEFAULT_MAX_QUEUE_SIZE = 0

    # The maximum number of seconds a thread in the pool may remain idle before
    # being reclaimed (unless overridden during construction).
    DEFAULT_THREAD_IDLETIMEOUT = 60

    OVERFLOW_POLICIES = [:abort, :discard, :caller_runs]

    # The maximum number of threads that may be created in the pool.
    attr_reader :max_length

    attr_reader :max_queue

    # Create a new thread pool.
    #
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
    def initialize(opts = {})
      min_length = opts.fetch(:min_threads, DEFAULT_MIN_POOL_SIZE).to_i
      @max_length = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
      idletime = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
      @max_queue = opts.fetch(:max_queue, DEFAULT_MAX_QUEUE_SIZE).to_i
      overflow_policy = opts.fetch(:overflow_policy, :abort)

      raise ArgumentError.new('max_threads must be greater than zero') if @max_length <= 0
      raise ArgumentError.new("#{overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.include?(overflow_policy)
    end

    def min_length
    end

    def max_length
    end

    def length
    end
    alias_method :current_length, :length

    def largest_length
    end

    def scheduled_task_count
    end

    def completed_task_count
    end

    def idletime
    end

    def queue_length
    end

    def remaining_capacity
    end

    # Is the thread pool running?
    #
    # @return [Boolean] +true+ when running, +false+ when shutting down or shutdown
    def running?
    end

    # Is the thread pool shutdown?
    #
    # @return [Boolean] +true+ when shutdown, +false+ when shutting down or running
    def shutdown?
    end

    # Were all tasks completed before shutdown?
    #
    # @return [Boolean] +true+ if shutdown and all tasks completed else +false+
    def terminated?
    end

    # Block until thread pool shutdown is complete or until +timeout+ seconds have
    # passed.
    #
    # @note Does not initiate shutdown or termination. Either +shutdown+ or +kill+
    #   must be called before this method (or on another thread).
    #
    # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean] +true+ if shutdown complete or false on +timeout+
    def wait_for_termination(timeout)
    end

    # Submit a task to the thread pool for asynchronous processing.
    #
    # @param [Array] args zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] +true+ if the task is queued, +false+ if the thread pool
    #   is not running
    #
    # @raise [ArgumentError] if no task is given
    def post(*args)
    end

    # Submit a task to the thread pool for asynchronous processing.
    #
    # @param [Proc] task the asynchronous task to perform
    #
    # @return [self] returns itself
    def <<(task)
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the
    # thread pool is not running.
    def shutdown
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
    end
  end
end
