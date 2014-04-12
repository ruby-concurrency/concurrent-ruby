if RUBY_PLATFORM == 'java'
  require_relative 'executor'

  module Concurrent

    # @!macro single_thread_executor
    class JavaSingleThreadExecutor
      include JavaExecutor

      # Create a new thread pool.
      #
      # @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
      # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
      def initialize(opts = {})
        @executor = java.util.concurrent.Executors.newSingleThreadExecutor
        set_shutdown_hook
      end
    end
  end
end
