require 'concurrent/executor/ruby_fixed_thread_pool'

module Concurrent

  if RUBY_PLATFORM == 'java'

    require 'concurrent/executor/java_fixed_thread_pool'

    # @!macro [attach] fixed_thread_pool
    #
    #   A thread pool with a set number of threads. The number of threads in the pool
    #   is set on construction and remains constant. When all threads are busy new
    #   tasks `#post` to the thread pool are enqueued until a thread becomes available.
    #   Should a thread crash for any reason the thread will immediately be removed
    #   from the pool and replaced.
    #
    #   The API and behavior of this class are based on Java's `FixedThreadPool`
    #
    #   @see Concurrent::RubyFixedThreadPool
    #   @see Concurrent::JavaFixedThreadPool
    #
    # @!macro [attach] thread_pool_options
    #
    #   Thread pools support several configuration options:
    #
    #   * `idletime`: The number of seconds that a thread may be idle before being reclaimed.
    #   * `max_queue`: The maximum number of tasks that may be waiting in the work queue at
    #     any one time. When the queue size reaches `max_queue` subsequent tasks will be
    #     rejected in accordance with the configured `fallback_policy`.
    #   * `stop_on_exit`: When true (default) an `at_exit` handler will be registered which
    #     will stop the thread pool when the application exits. See below for more information
    #     on shutting down thread pools.
    #   * `fallback_policy`: The policy defining how rejected tasks are handled.
    #
    #   Three fallback policies are supported:
    #
    #   * `:abort`: Raise a `RejectedExecutionError` exception and discard the task.
    #   * `:discard`: Discard the task and return false.
    #   * `:caller_runs`: Execute the task on the calling thread.
    #
    #   **Shutting Down Thread Pools**
    #
    #   Killing a thread pool while tasks are still being processed, either by calling
    #   the `#kill` method or at application exit, will have unpredictable results. There
    #   is no way for the thread pool to know what resources are being used by the
    #   in-progress tasks. When those tasks are killed the impact on those resources
    #   cannot be predicted. The *best* practice is to explicitly shutdown all thread
    #   pools using the provided methods:
    #
    #   * Call `#shutdown` to initiate an orderly termination of all in-progress tasks
    #   * Call `#wait_for_termination` with an appropriate timeout interval an allow
    #     the orderly shutdown to complete
    #   * Call `#kill` *only when* the thread pool fails to shutdown in the allotted time
    #
    #   On some runtime platforms (most notably the JVM) the application will not
    #   exit until all thread pools have been shutdown. To prevent applications from
    #   "hanging" on exit all thread pools include an `at_exit` handler that will
    #   stop the thread pool when the application exists. This handler uses a brute
    #   force method to stop the pool and makes no guarantees regarding resources being
    #   used by any tasks still running. Registration of this `at_exit` handler can be
    #   prevented by setting the thread pool's constructor `:stop_on_exit` option to
    #   `false` when the thread pool is created. All thread pools support this option.
    #
    #   ```ruby
    #   pool1 = Concurrent::FixedThreadPool.new(5) # an `at_exit` handler will be registered
    #   pool2 = Concurrent::FixedThreadPool.new(5, stop_on_exit: false) # prevent `at_exit` handler registration
    #   ```
    #
    #   @note Failure to properly shutdown a thread pool can lead to unpredictable results.
    #     Please read *Shutting Down Thread Pools* for more information.
    #
    #   @note When running on the JVM (JRuby) this class will inherit from `JavaThreadPoolExecutor`.
    #     On all other platforms it will inherit from `RubyThreadPoolExecutor`.
    #
    #   @see Concurrent::RubyThreadPoolExecutor
    #   @see Concurrent::JavaThreadPoolExecutor
    #
    #   @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html Java Tutorials: Thread Pools
    #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html Java Executors class
    #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html Java ExecutorService interface
    #   @see http://ruby-doc.org//core-2.2.0/Kernel.html#method-i-at_exit Kernel#at_exit
    class FixedThreadPool < JavaFixedThreadPool
    end
  else
    # @!macro fixed_thread_pool
    # @!macro thread_pool_options
    class FixedThreadPool < RubyFixedThreadPool
    end
  end
end
