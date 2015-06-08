require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  if Concurrent.on_jruby?
    require 'concurrent/executor/java_thread_pool_executor'
  end

  ThreadPoolExecutorImplementation = case
                                     when Concurrent.on_jruby?
                                       JavaThreadPoolExecutor
                                     else
                                       RubyThreadPoolExecutor
                                     end
  private_constant :ThreadPoolExecutorImplementation

  # @!macro [attach] thread_pool_executor
  #
  #   An abstraction composed of one or more threads and a task queue. Tasks
  #   (blocks or `proc` objects) are submit to the pool and added to the queue.
  #   The threads in the pool remove the tasks and execute them in the order
  #   they were received. When there are more tasks queued than there are
  #   threads to execute them the pool will create new threads, up to the
  #   configured maximum. Similarly, threads that are idle for too long will
  #   be garbage collected, down to the configured minimum options. Should a
  #   thread crash it, too, will be garbage collected.
  #
  #   `ThreadPoolExecutor` is based on the Java class of the same name. From
  #   the official Java documentationa;
  #
  #   > Thread pools address two different problems: they usually provide
  #   > improved performance when executing large numbers of asynchronous tasks,
  #   > due to reduced per-task invocation overhead, and they provide a means
  #   > of bounding and managing the resources, including threads, consumed
  #   > when executing a collection of tasks. Each ThreadPoolExecutor also
  #   > maintains some basic statistics, such as the number of completed tasks.
  #   >
  #   > To be useful across a wide range of contexts, this class provides many
  #   > adjustable parameters and extensibility hooks. However, programmers are
  #   > urged to use the more convenient Executors factory methods
  #   > [CachedThreadPool] (unbounded thread pool, with automatic thread reclamation),
  #   > [FixedThreadPool] (fixed size thread pool) and [SingleThreadExecutor] (single
  #   > background thread), that preconfigure settings for the most common usage
  #   > scenarios.
  #
  # @!macro thread_pool_options
  class ThreadPoolExecutor < ThreadPoolExecutorImplementation

    # @!macro [new] thread_pool_executor_constant_default_max_pool_size
    #   Default maximum number of threads that will be created in the pool.

    # @!macro [new] thread_pool_executor_constant_default_min_pool_size
    #   Default minimum number of threads that will be retained in the pool.

    # @!macro [new] thread_pool_executor_constant_default_max_queue_size
    #   Default maximum number of tasks that may be added to the task queue.

    # @!macro [new] thread_pool_executor_constant_default_thread_timeout
    #   Default maximum number of seconds a thread in the pool may remain idle
    #   before being reclaimed.

    # @!macro [new] thread_pool_executor_attr_reader_max_length
    #   The maximum number of threads that may be created in the pool.
    #   @return [Integer] The maximum number of threads that may be created in the pool.

    # @!macro [new] thread_pool_executor_attr_reader_min_length
    #   The minimum number of threads that may be retained in the pool.
    #   @return [Integer] The minimum number of threads that may be retained in the pool.

    # @!macro [new] thread_pool_executor_attr_reader_largest_length
    #   The largest number of threads that have been created in the pool since construction.
    #   @return [Integer] The largest number of threads that have been created in the pool since construction.

    # @!macro [new] thread_pool_executor_attr_reader_scheduled_task_count
    #   The number of tasks that have been scheduled for execution on the pool since construction.
    #   @return [Integer] The number of tasks that have been scheduled for execution on the pool since construction.

    # @!macro [new] thread_pool_executor_attr_reader_completed_task_count
    #   The number of tasks that have been completed by the pool since construction.
    #   @return [Integer] The number of tasks that have been completed by the pool since construction.

    # @!macro [new] thread_pool_executor_attr_reader_idletime
    #   The number of seconds that a thread may be idle before being reclaimed.
    #   @return [Integer] The number of seconds that a thread may be idle before being reclaimed.

    # @!macro [new] thread_pool_executor_attr_reader_max_queue
    #   The maximum number of tasks that may be waiting in the work queue at any one time.
    #   When the queue size reaches `max_queue` subsequent tasks will be rejected in
    #   accordance with the configured `fallback_policy`.
    #
    #   @return [Integer] The maximum number of tasks that may be waiting in the work queue at any one time.
    #     When the queue size reaches `max_queue` subsequent tasks will be rejected in
    #     accordance with the configured `fallback_policy`.

    # @!macro [new] thread_pool_executor_attr_reader_length
    #   The number of threads currently in the pool.
    #   @return [Integer] The number of threads currently in the pool.

    # @!macro [new] thread_pool_executor_attr_reader_queue_length
    #   The number of tasks in the queue awaiting execution.
    #   @return [Integer] The number of tasks in the queue awaiting execution.

    # @!macro [new] thread_pool_executor_attr_reader_remaining_capacity
    #   Number of tasks that may be enqueued before reaching `max_queue` and rejecting
    #   new tasks. A value of -1 indicates that the queue may grow without bound.
    #
    #   @return [Integer] Number of tasks that may be enqueued before reaching `max_queue` and rejecting
    #     new tasks. A value of -1 indicates that the queue may grow without bound.

    # @!macro [new] thread_pool_executor_method_initialize
    #
    #   Create a new thread pool.
    #  
    #   @param [Hash] opts the options which configure the thread pool.
    #  
    #   @option opts [Integer] :max_threads (DEFAULT_MAX_POOL_SIZE) the maximum
    #     number of threads to be created
    #   @option opts [Integer] :min_threads (DEFAULT_MIN_POOL_SIZE) the minimum
    #     number of threads to be retained
    #   @option opts [Integer] :idletime (DEFAULT_THREAD_IDLETIMEOUT) the maximum
    #     number of seconds a thread may be idle before being reclaimed
    #   @option opts [Integer] :max_queue (DEFAULT_MAX_QUEUE_SIZE) the maximum
    #     number of tasks allowed in the work queue at any one time; a value of
    #     zero means the queue may grow without bound
    #   @option opts [Symbol] :fallback_policy (:abort) the policy for handling new
    #     tasks that are received when the queue size has reached
    #     `max_queue` or the executor has shut down
    #  
    #   @raise [ArgumentError] if `:max_threads` is less than one
    #   @raise [ArgumentError] if `:min_threads` is less than zero
    #   @raise [ArgumentError] if `:fallback_policy` is not one of the values specified
    #     in `FALLBACK_POLICIES`
    #  
    #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html



    # @!attribute [r] fallback_policy
    #   @!macro executor_service_attr_reader_fallback_policy

    # @!attribute [r] max_length
    #   @!macro thread_pool_executor_attr_reader_max_length

    # @!attribute [r] min_length
    #   @!macro thread_pool_executor_attr_reader_min_length

    # @!attribute [r] largest_length
    #   @!macro thread_pool_executor_attr_reader_largest_length

    # @!attribute [r] scheduled_task_count
    #   @!macro thread_pool_executor_attr_reader_scheduled_task_count

    # @!attribute [r] completed_task_count
    #   @!macro thread_pool_executor_attr_reader_completed_task_count

    # @!attribute [r] idletime
    #   @!macro thread_pool_executor_attr_reader_idletime

    # @!attribute [r] max_queue
    #   @!macro thread_pool_executor_attr_reader_max_queue

    # @!attribute [r] length
    #   @!macro thread_pool_executor_attr_reader_length

    # @!attribute [r] queue_length
    #   @!macro thread_pool_executor_attr_reader_queue_length

    # @!attribute [r] remaining_capacity
    #   @!macro thread_pool_executor_attr_reader_remaining_capacity

    # @!method initialize(opts = {})
    #   @!macro thread_pool_executor_method_initialize

    # @!method can_overflow?
    #   @!macro executor_service_method_can_overflow_question





    # @!method shutdown
    #   @!macro executor_service_method_shutdown

    # @!method kill
    #   @!macro executor_service_method_kill

    # @!method wait_for_termination(timeout = nil)
    #   @!macro executor_service_method_wait_for_termination


    # @!method running?
    #   @!macro executor_service_method_running_question

    # @!method shuttingdown?
    #   @!macro executor_service_method_shuttingdown_question

    # @!method shutdown?
    #   @!macro executor_service_method_shutdown_question

    # @!method auto_terminate?
    #   @!macro executor_service_method_auto_terminate_question

    # @!method auto_terminate=(value)
    #   @!macro executor_service_method_auto_terminate_setter
  end
end
