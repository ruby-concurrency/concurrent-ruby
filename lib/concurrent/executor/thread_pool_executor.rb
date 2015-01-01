require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  if RUBY_PLATFORM == 'java'
    require 'concurrent/executor/java_thread_pool_executor'
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
    #   Thread pools support several configuration options:
    #
    #   * `max_threads`: The maximum number of threads that may be created in the pool.
    #   * `min_threads`: The minimum number of threads that may be retained in the pool.
    #   * `idletime`: The number of seconds that a thread may be idle before being reclaimed.
    #   * `max_queue`: The maximum number of tasks that may be waiting in the work queue at
    #     any one time. When the queue size reaches `max_queue` subsequent tasks will be
    #     rejected in accordance with the configured `fallback_policy`.
    #   * `fallback_policy`: The policy defining how rejected tasks are handled.    #
    #
    #   Three fallback policies are supported:
    #
    #   * `:abort`: Raise a `RejectedExecutionError` exception and discard the task.
    #   * `:discard`: Discard the task and return false.
    #   * `:caller_runs`: Execute the task on the calling thread.
    #
    #   @note When running on the JVM (JRuby) this class will inherit from `JavaThreadPoolExecutor`.
    #     On all other platforms it will inherit from `RubyThreadPoolExecutor`.
    #
    #   @see Concurrent::RubyThreadPoolExecutor
    #   @see Concurrent::JavaThreadPoolExecutor
    #
    #   @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
    #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
    #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
    class ThreadPoolExecutor < JavaThreadPoolExecutor
    end
  else
    # @!macro thread_pool_executor
    class ThreadPoolExecutor < RubyThreadPoolExecutor
    end
  end
end
