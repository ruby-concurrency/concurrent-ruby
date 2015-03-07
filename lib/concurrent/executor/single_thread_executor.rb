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
    #   @see Concurrent::RubySingleThreadExecutor
    #   @see Concurrent::JavaSingleThreadExecutor
    #
    # @!macro thread_pool_options
    class SingleThreadExecutor < JavaSingleThreadExecutor
    end
  else
    # @!macro single_thread_executor
    # @!macro thread_pool_options
    class SingleThreadExecutor < RubySingleThreadExecutor
    end
  end
end
