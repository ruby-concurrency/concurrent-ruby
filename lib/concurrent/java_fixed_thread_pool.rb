if defined? java.util

  require 'concurrent/utilities'

  module Concurrent

    # @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
    # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
    class JavaFixedThreadPool

      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newFixedThreadPool-int-
      def initialize(num_threads = Concurrent::processor_count)
        @num_threads = num_threads.to_i
        raise ArgumentError.new('number of threads must be greater than zero') if @num_threads < 1

        @executor = java.util.concurrent.Executors.newFixedThreadPool(@num_threads)
      end

      def running?
        ! (shutdown? || terminated?)
      end

      def shutdown?
        @executor.isShutdown
      end

      def terminated?
        @executor.isTerminated
      end

      def wait_for_termination(timeout)
        @executor.awaitTermination(timeout.to_i, java.util.concurrent.TimeUnit::SECONDS)
      end

      def post(*args)
        raise ArgumentError.new('no block given') unless block_given?
        @executor.submit{ yield(*args) }
        return true
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        return false
      end

      def <<(block)
        @executor.submit(&block)
      rescue Java::JavaUtilConcurrent::RejectedExecutionException => ex
        # do nothing
      ensure
        return self
      end

      def shutdown
        @executor.shutdown
        return nil
      end

      def kill
        @executor.shutdownNow
        return nil
      end

      def length
        running? ? @num_threads : 0
      end
      alias_method :size, :length
    end
  end
end
