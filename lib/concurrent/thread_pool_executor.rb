require 'concurrent/ruby_thread_pool_executor'

module Concurrent

  if RUBY_PLATFORM == 'java'
    require 'concurrent/java_thread_pool_executor'
    # @!macro [attach] thread_pool_executor
    #
    #   A thread pool...
    #
    #   The API and behavior of this class are based on Java's `ThreadPoolExecutor`
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
    #   @see http://stackoverflow.com/questions/17957382/fixedthreadpool-vs-fixedthreadpool-the-lesser-of-two-evils
    class ThreadPoolExecutor < JavaThreadPoolExecutor
    end
  else
    # @!macro thread_pool_executor
    class ThreadPoolExecutor < RubyThreadPoolExecutor
    end
  end
end
