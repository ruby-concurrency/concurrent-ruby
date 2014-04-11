require 'concurrent/executor/ruby_cached_thread_pool'

module Concurrent

  if RUBY_PLATFORM == 'java'
    require 'concurrent/executor/java_cached_thread_pool'
    # @!macro [attach] cached_thread_pool
    #   A thread pool that dynamically grows and shrinks to fit the current workload.
    #   New threads are created as needed, existing threads are reused, and threads
    #   that remain idle for too long are killed and removed from the pool. These
    #   pools are particularly suited to applications that perform a high volume of
    #   short-lived tasks.
    #
    #   On creation a `CachedThreadPool` has zero running threads. New threads are
    #   created on the pool as new operations are `#post`. The size of the pool
    #   will grow until `#max_length` threads are in the pool or until the number
    #   of threads exceeds the number of running and pending operations. When a new
    #   operation is post to the pool the first available idle thread will be tasked
    #   with the new operation.
    #
    #   Should a thread crash for any reason the thread will immediately be removed
    #   from the pool. Similarly, threads which remain idle for an extended period
    #   of time will be killed and reclaimed. Thus these thread pools are very
    #   efficient at reclaiming unused resources.
    #
    #   The API and behavior of this class are based on Java's `CachedThreadPool`
    #
    #   @note When running on the JVM (JRuby) this class will inherit from `JavaCachedThreadPool`.
    #     On all other platforms it will inherit from `RubyCachedThreadPool`.
    #
    #   @see Concurrent::RubyCachedThreadPool
    #   @see Concurrent::JavaCachedThreadPool
    #
    #   @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
    #   @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
    #   @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
    class CachedThreadPool < JavaCachedThreadPool
    end
  else
    # @!macro cached_thread_pool
    class CachedThreadPool < RubyCachedThreadPool
    end
  end
end
