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
    #   @note When running on the JVM (JRuby) this class will inherit from `JavaFixedThreadPool`.
    #     On all other platforms it will inherit from `RubyFixedThreadPool`.
    #
    #   @see Concurrent::RubyFixedThreadPool
    #   @see Concurrent::JavaFixedThreadPool
    #
    #   @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
    #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
    #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
    class FixedThreadPool < JavaFixedThreadPool
    end
  else
    # @!macro fixed_thread_pool
    class FixedThreadPool < RubyFixedThreadPool
    end
  end
end
