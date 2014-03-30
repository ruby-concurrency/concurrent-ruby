if defined? java.util

  require 'concurrent/java_thread_pool_executor'
  require 'concurrent/utilities'

  module Concurrent

    # @!macro fixed_thread_pool
    class JavaFixedThreadPool < JavaThreadPoolExecutor

      # Create a new thread pool.
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newFixedThreadPool-int-
      def initialize(num_threads = Concurrent::processor_count)
        raise ArgumentError.new('number of threads must be greater than zero') if num_threads < 1

        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          num_threads, num_threads,
          0, java.util.concurrent.TimeUnit::SECONDS,
          java.util.concurrent.LinkedBlockingQueue.new,
          java.util.concurrent.ThreadPoolExecutor::AbortPolicy.new)
      end
    end
  end
end
