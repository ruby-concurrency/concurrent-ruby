if Concurrent.on_jruby?
  require 'concurrent/executor/executor_service'

  module Concurrent

    # @!macro thread_pool_executor
    # @!macro thread_pool_options
    class JavaThreadPoolExecutor < JavaExecutorService

      # Default maximum number of threads that will be created in the pool.
      DEFAULT_MAX_POOL_SIZE = java.lang.Integer::MAX_VALUE # 2147483647

      # Default minimum number of threads that will be retained in the pool.
      DEFAULT_MIN_POOL_SIZE = 0

      # Default maximum number of tasks that may be added to the task queue.
      DEFAULT_MAX_QUEUE_SIZE = 0

      # Default maximum number of seconds a thread in the pool may remain idle
      # before being reclaimed.
      DEFAULT_THREAD_IDLETIMEOUT = 60

      # The maximum number of threads that may be created in the pool.
      attr_reader :max_length

      # The maximum number of tasks that may be waiting in the work queue at any one time.
      # When the queue size reaches `max_queue` subsequent tasks will be rejected in
      # accordance with the configured `fallback_policy`.
      attr_reader :max_queue

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
      #   zero means the queue may grow without bound
      # @option opts [Symbol] :fallback_policy (:abort) the policy for handling new
      #   tasks that are received when the queue size has reached
      #   `max_queue` or the executir has shut down
      #
      # @raise [ArgumentError] if `:max_threads` is less than one
      # @raise [ArgumentError] if `:min_threads` is less than zero
      # @raise [ArgumentError] if `:fallback_policy` is not one of the values specified
      #   in `FALLBACK_POLICIES`
      #
      # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
      def initialize(opts = {})
        super(opts)
      end

      # @!macro executor_service_method_can_overflow_question
      def can_overflow?
        @max_queue != 0
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

      # Is the thread pool running?
      #
      # @return [Boolean] `true` when running, `false` when shutting down or shutdown
      def running?
        super && !@executor.isTerminating
      end

      protected

      def ns_initialize(opts)
        min_length = opts.fetch(:min_threads, DEFAULT_MIN_POOL_SIZE).to_i
        max_length = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
        idletime = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
        @max_queue = opts.fetch(:max_queue, DEFAULT_MAX_QUEUE_SIZE).to_i
        @fallback_policy = opts.fetch(:fallback_policy, opts.fetch(:overflow_policy, :abort))
        deprecated ' :overflow_policy is deprecated terminology, please use :fallback_policy instead' if opts.has_key?(:overflow_policy)

        raise ArgumentError.new("`max_threads` cannot be less than #{DEFAULT_MIN_POOL_SIZE}") if max_length < DEFAULT_MIN_POOL_SIZE
        raise ArgumentError.new("`max_threads` cannot be greater than #{DEFAULT_MAX_POOL_SIZE}") if max_length > DEFAULT_MAX_POOL_SIZE
        raise ArgumentError.new("`min_threads` cannot be less than #{DEFAULT_MIN_POOL_SIZE}") if min_length < DEFAULT_MIN_POOL_SIZE
        raise ArgumentError.new("`min_threads` cannot be more than `max_threads`") if min_length > max_length
        raise ArgumentError.new("#{fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICY_CLASSES.include?(@fallback_policy)

        if @max_queue == 0
          queue = java.util.concurrent.LinkedBlockingQueue.new
        else
          queue = java.util.concurrent.LinkedBlockingQueue.new(@max_queue)
        end

        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          min_length, max_length,
          idletime, java.util.concurrent.TimeUnit::SECONDS,
          queue, FALLBACK_POLICY_CLASSES[@fallback_policy].new)

        self.auto_terminate = opts.fetch(:auto_terminate, true)
      end
    end
  end
end
