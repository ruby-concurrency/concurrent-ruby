if defined? java.util

  require 'concurrent/java_thread_pool_executor'

  module Concurrent

    # @!macro cached_thread_pool
    class JavaCachedThreadPool < JavaThreadPoolExecutor

      # The maximum number of threads that may be created in the pool
      # (unless overridden during construction).
      DEFAULT_MAX_POOL_SIZE = java.lang.Integer::MAX_VALUE # 2147483647

      # The maximum number of seconds a thread in the pool may remain idle before
      # being reclaimed (unless overridden during construction).
      DEFAULT_THREAD_IDLETIME = 60

      # The maximum number of threads that may be created in the pool.
      attr_reader :max_length

      # Create a new thread pool.
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newCachedThreadPool--
      def initialize(opts = {})
        idletime = (opts[:thread_idletime] || opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
        raise ArgumentError.new('idletime must be greater than zero') if idletime <= 0

        @max_length = opts[:max_threads] || opts[:max] || DEFAULT_MAX_POOL_SIZE
        raise ArgumentError.new('maximum_number of threads must be greater than zero') if @max_length <= 0

        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          0, @max_length,
          idletime, java.util.concurrent.TimeUnit::SECONDS,
          java.util.concurrent.SynchronousQueue.new,
          java.util.concurrent.ThreadPoolExecutor::AbortPolicy.new)
      end
    end
  end
end
