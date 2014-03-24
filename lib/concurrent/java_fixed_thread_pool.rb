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

        @executor = java.util.concurrent.Executors.newFixedThreadPool(@num_threads)
      end

      # The number of threads currently in the pool.
      #
      # @return [Integer] a non-zero value when the pool is running,
      #   zero when the pool is shutdown
      def length
        running? ? @num_threads : 0
      end
      alias_method :size, :length
    end
  end
end
