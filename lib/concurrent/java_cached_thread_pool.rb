if defined? java.util

  require 'concurrent/java_abstract_thread_pool'

  module Concurrent

    # @!macro cached_thread_pool
    class JavaCachedThreadPool
      include JavaAbstractThreadPool

      # Create a new thread pool.
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newCachedThreadPool--
      def initialize(opts = {})
        @executor = java.util.concurrent.Executors.newCachedThreadPool
      end

      # The number of threads currently in the pool.
      #
      # @return [Integer] a non-zero value when the pool is running,
      #   zero when the pool is shutdown
      def length
        running? ? 1 : 0
      end
      alias_method :size, :length
    end
  end
end
