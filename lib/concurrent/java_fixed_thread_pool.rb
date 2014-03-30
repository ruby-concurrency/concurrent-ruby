if defined? java.util

  require 'concurrent/java_abstract_thread_pool'
  require 'concurrent/utilities'

  module Concurrent

    # @!macro fixed_thread_pool
    class JavaFixedThreadPool
      include JavaAbstractThreadPool

      # Create a new thread pool.
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newFixedThreadPool-int-
      def initialize(num_threads = Concurrent::processor_count)
        @num_threads = num_threads.to_i
        raise ArgumentError.new('number of threads must be greater than zero') if @num_threads < 1

        #@executor = java.util.concurrent.Executors.newFixedThreadPool(@num_threads)
        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          @num_threads, @num_threads,
          0, java.util.concurrent.TimeUnit::SECONDS,
          java.util.concurrent.LinkedBlockingQueue.new,
          java.util.concurrent.ThreadPoolExecutor::AbortPolicy.new)

        #p = java.util.concurrent.Executors.newFixedThreadPool(10)
        #p.getCorePoolSize #=> 10
        #p.getMaximumPoolSize #=> 10
        #p.getKeepAliveTime(java.util.concurrent.TimeUnit::SECONDS) #=> 0
        #p.getQueue #=> #<Java::JavaUtilConcurrent::LinkedBlockingQueue:0x97dabf4>

        #p.getActiveCount #=> 0
        #p.getQueue.size #=> 0
        #p.getRejectedExecutionHandler #=> #<Java::JavaUtilConcurrent::ThreadPoolExecutor::AbortPolicy:0x7e41986c>
      end
    end
  end
end
