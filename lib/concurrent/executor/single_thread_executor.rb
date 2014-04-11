require 'concurrent/executor/ruby_single_thread_executor'

module Concurrent

  if RUBY_PLATFORM == 'java'

    require 'concurrent/executor/java_single_thread_executor'

    # @!macro [attach] single_thread_executor
    #
    #   A thread pool with a set number of threads. The number of threads in the pool
    #   is set on construction and remains constant. When all threads are busy new
    #   tasks `#post` to the thread pool are enqueued until a thread becomes available.
    #   Should a thread crash for any reason the thread will immediately be removed
    #   from the pool and replaced.
    #
    #   The API and behavior of this class are based on Java's `SingleThreadExecutor`
    #
    #   @note When running on the JVM (JRuby) this class will inherit from `JavaSingleThreadExecutor`.
    #     On all other platforms it will inherit from `RubySingleThreadExecutor`.
    #
    #   @see Concurrent::RubySingleThreadExecutor
    #   @see Concurrent::JavaSingleThreadExecutor
    #
    #   @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
    #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
    #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
    class SingleThreadExecutor < JavaSingleThreadExecutor
    end
  else
    # @!macro single_thread_executor
    class SingleThreadExecutor < RubySingleThreadExecutor
    end
  end
end
