if RUBY_PLATFORM == 'java'
  require_relative 'executor'

  module Concurrent

    # @!macro thread_pool_executor
    class JavaThreadPoolExecutor
      include Executor

      # Default maximum number of threads that will be created in the pool.
      DEFAULT_MAX_POOL_SIZE = java.lang.Integer::MAX_VALUE # 2147483647

      # Default minimum number of threads that will be retained in the pool.
      DEFAULT_MIN_POOL_SIZE = 0

      # Default maximum number of tasks that may be added to the task queue.
      DEFAULT_MAX_QUEUE_SIZE = 0

      # Default maximum number of seconds a thread in the pool may remain idle
      # before being reclaimed.
      DEFAULT_THREAD_IDLETIMEOUT = 60

      # The set of possible overflow policies that may be set at thread pool creation.
      OVERFLOW_POLICIES = {
        abort: java.util.concurrent.ThreadPoolExecutor::AbortPolicy,
        discard: java.util.concurrent.ThreadPoolExecutor::DiscardPolicy,
        caller_runs: java.util.concurrent.ThreadPoolExecutor::CallerRunsPolicy
      }.freeze

      # The maximum number of threads that may be created in the pool.
      attr_reader :max_length

      # The maximum number of tasks that may be waiting in the work queue at any one time.
      # When the queue size reaches `max_queue` subsequent tasks will be rejected in
      # accordance with the configured `overflow_policy`.
      attr_reader :max_queue

      # The policy defining how rejected tasks (tasks received once the queue size reaches
      # the configured `max_queue`) are handled. Must be one of the values specified in
      # `OVERFLOW_POLICIES`.
      attr_reader :overflow_policy

      # Create a new thread pool.
      #
      # @param [Hash] opts the options which configure the thread pool
      #
      # @option opts [Integer] :max_threads (DEFAULT_MAX_POOL_SIZE) the maximum
      #   number of threads to be created
      # @option opts [Integer] :min_threads (DEFAULT_MIN_POOL_SIZE) the minimum
      #   number of threads to be retained
      # @option opts [Integer] :idletime (DEFAULT_THREAD_IDLETIMEOUT) the maximum
      #   number of seconds a thread may be idle before being reclaimed
      # @option opts [Integer] :max_queue (DEFAULT_MAX_QUEUE_SIZE) the maximum
      #   number of tasks allowed in the work queue at any one time; a value of
      #   zero means the queue may grow without bounnd
      # @option opts [Symbol] :overflow_policy (:abort) the policy for handling new
      #   tasks that are received when the queue size has reached `max_queue`
      #
      # @raise [ArgumentError] if `:max_threads` is less than one
      # @raise [ArgumentError] if `:min_threads` is less than zero
      # @raise [ArgumentError] if `:overflow_policy` is not one of the values specified
      #   in `OVERFLOW_POLICIES`
      #
      # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
      def initialize(opts = {})
        min_length = opts.fetch(:min_threads, DEFAULT_MIN_POOL_SIZE).to_i
        max_length = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
        idletime = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
        @max_queue = opts.fetch(:max_queue, DEFAULT_MAX_QUEUE_SIZE).to_i
        @overflow_policy = opts.fetch(:overflow_policy, :abort)

        raise ArgumentError.new('max_threads must be greater than zero') if max_length <= 0
        raise ArgumentError.new('min_threads cannot be less than zero') if min_length < 0
        raise ArgumentError.new("#{@overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.keys.include?(@overflow_policy)

        if min_length == 0 && @max_queue == 0
          queue = java.util.concurrent.SynchronousQueue.new
        elsif @max_queue == 0
          queue = java.util.concurrent.LinkedBlockingQueue.new
        else
          queue = java.util.concurrent.LinkedBlockingQueue.new(@max_queue)
        end

        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          min_length, max_length,
          idletime, java.util.concurrent.TimeUnit::SECONDS,
          queue, OVERFLOW_POLICIES[@overflow_policy].new)

        # without this the process may fail to exit
        at_exit { self.kill }
      end

      # The minimum number of threads that may be retained in the pool.
      #
      # @return [Integer] the min_length
      def min_length
        @executor.getCorePoolSize
      end

      # The maximum number of threads that may be created in the pool.
      #
      # @return [Integer] the max_length
      def max_length
        @executor.getMaximumPoolSize
      end

      # The number of threads currently in the pool.
      #
      # @return [Integer] the length
      def length
        @executor.getPoolSize
      end
      alias_method :current_length, :length

      # The largest number of threads that have been created in the pool since construction.
      #
      # @return [Integer] the largest_length
      def largest_length
        @executor.getLargestPoolSize
      end

      # The number of tasks that have been scheduled for execution on the pool since construction.
      #
      # @return [Integer] the scheduled_task_count
      def scheduled_task_count
        @executor.getTaskCount
      end

      # The number of tasks that have been completed by the pool since construction.
      #
      # @return [Integer] the completed_task_count
      def completed_task_count
        @executor.getCompletedTaskCount
      end

      # The number of seconds that a thread may be idle before being reclaimed.
      #
      # @return [Integer] the idletime
      def idletime
        @executor.getKeepAliveTime(java.util.concurrent.TimeUnit::SECONDS)
      end

      # The number of tasks in the queue awaiting execution.
      #
      # @return [Integer] the queue_length
      def queue_length
        @executor.getQueue.size
      end

      # Number of tasks that may be enqueued before reaching `max_queue` and rejecting
      # new tasks. A value of -1 indicates that the queue may grow without bound.
      #
      # @return [Integer] the remaining_capacity
      def remaining_capacity
        @max_queue == 0 ? -1 : @executor.getQueue.remainingCapacity
      end

      # This method is deprecated and will be removed soon.
      # This method is supost to return the threads status, but Java API doesn't
      # provide a way to get the thread status. So we return an empty Array instead.
      def status
        warn '[DEPRECATED] `status` is deprecated and will be removed soon.'
        warn "Calls to `status` return an empty Array. Java ThreadPoolExecutor does not provide thread's status."
        []
      end

      # Is the thread pool running?
      #
      # @return [Boolean] `true` when running, `false` when shutting down or shutdown
      def running?
        ! (@executor.isShutdown || @executor.isTerminated || @executor.isTerminating)
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

      # Begin an orderly shutdown. Tasks already in the queue will be executed,
      # but no new tasks will be accepted. Has no additional effect if the
      # thread pool is not running.
      def shutdown
        @executor.shutdown
        @executor.getQueue.clear
        return nil
      end

      # Begin an immediate shutdown. In-progress tasks will be allowed to
      # complete but enqueued tasks will be dismissed and no new tasks
      # will be accepted. Has no additional effect if the thread pool is
      # not running.
      def kill
        @executor.shutdownNow
        @executor.getQueue.clear
        return nil
      end
    end
  end
end
