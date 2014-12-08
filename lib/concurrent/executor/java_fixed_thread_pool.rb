if RUBY_PLATFORM == 'java'

  require 'concurrent/executor/java_thread_pool_executor'

  module Concurrent

    # @!macro fixed_thread_pool
    class JavaFixedThreadPool < JavaThreadPoolExecutor

      # Create a new thread pool.
      #
      # @param [Hash] opts the options defining pool behavior.
      # @option opts [Symbol] :fallback_policy (`:abort`) the fallback policy
      #
      # @raise [ArgumentError] if `num_threads` is less than or equal to zero
      # @raise [ArgumentError] if `fallback_policy` is not a known policy
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newFixedThreadPool-int-
      def initialize(num_threads, opts = {})

        opts = {
            min_threads: num_threads,
            max_threads: num_threads
        }.merge(opts)
        super(opts)

        set_shutdown_hook
      end
    end
  end
end
