if defined? java.util

  module Concurrent

    # @!macro thread_pool_executor
    class JavaThreadPoolExecutor

      # The maximum number of threads that will be created in the pool
      # (unless overridden during construction).
      DEFAULT_MAX_POOL_SIZE = java.lang.Integer::MAX_VALUE # 2147483647

      # The minimum number of threads that will be created in the pool
      # (unless overridden during construction).
      DEFAULT_MIN_POOL_SIZE = 0

      DEFAULT_MAX_QUEUE_SIZE = 0

      # The maximum number of seconds a thread in the pool may remain idle before
      # being reclaimed (unless overridden during construction).
      DEFAULT_THREAD_IDLETIMEOUT = 60

      OVERFLOW_POLICIES = {
        abort: java.util.concurrent.ThreadPoolExecutor::AbortPolicy,
        discard: java.util.concurrent.ThreadPoolExecutor::DiscardPolicy,
        caller_runs: java.util.concurrent.ThreadPoolExecutor::CallerRunsPolicy
      }.freeze

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
        raise ArgumentError.new("#{overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.keys.include?(overflow_policy)

        if min_length == 0 && max_queue == 0
          queue = java.util.concurrent.SynchronousQueue.new
        elsif max_queue == 0
          queue = java.util.concurrent.LinkedBlockingQueue.new
        else
          queue = java.util.concurrent.LinkedBlockingQueue.new(max_queue)
        end

        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          min_length, @max_length,
          idletime, java.util.concurrent.TimeUnit::SECONDS,
          queue, OVERFLOW_POLICIES[overflow_policy].new)
      end

      def min_length
        @executor.getCorePoolSize
      end

      def max_length
        @executor.getMaximumPoolSize
      end

      def length
        @executor.getPoolSize
      end
      alias_method :current_length, :length

      def largest_length
        @executor.getLargestPoolSize
      end

      def scheduled_task_count
        @executor.getTaskCount
      end

      def completed_task_count
        @executor.getCompletedTaskCount
      end

      def idletime
        @executor.getKeepAliveTime(java.util.concurrent.TimeUnit::SECONDS)
      end

      def queue_length
        @executor.getQueue.size
      end

      def remaining_capacity
        @executor.getQueue.remainingCapacity
      end

      # Is the thread pool running?
      #
      # @return [Boolean] +true+ when running, +false+ when shutting down or shutdown
      def running?
        ! (shutdown? || terminated?)
      end

      # Is the thread pool shutdown?
      #
      # @return [Boolean] +true+ when shutdown, +false+ when shutting down or running
      def shutdown?
        @executor.isShutdown
      end

      # Were all tasks completed before shutdown?
      #
      # @return [Boolean] +true+ if shutdown and all tasks completed else +false+
      def terminated?
        @executor.isTerminated
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
        @executor.awaitTermination(timeout.to_i, java.util.concurrent.TimeUnit::SECONDS)
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
        raise ArgumentError.new('no block given') unless block_given?
        @executor.submit{ yield(*args) }
        return true
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        return false
      end

      # Submit a task to the thread pool for asynchronous processing.
      #
      # @param [Proc] task the asynchronous task to perform
      #
      # @return [self] returns itself
      def <<(task)
        @executor.submit(&task)
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        # do nothing
      ensure
        return self
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
        return nil
      end
    end
  end
end
