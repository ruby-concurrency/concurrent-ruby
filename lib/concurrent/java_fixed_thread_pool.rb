if RUBY_PLATFORM == 'java'

  require 'concurrent/java_thread_pool_executor'

  module Concurrent

    # @!macro fixed_thread_pool
    class JavaFixedThreadPool < JavaThreadPoolExecutor

      # Create a new thread pool.
      #
      # @param [Hash] opts the options defining pool behavior.
      # @option opts [Symbol] :overflow_policy (`:abort`) the overflow policy
      #
      # @raise [ArgumentError] if `num_threads` is less than or equal to zero
      # @raise [ArgumentError] if `overflow_policy` is not a known policy
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newFixedThreadPool-int-
      def initialize(num_threads, opts = {})
        @overflow_policy = opts.fetch(:overflow_policy, :abort)
        @max_queue = 0

        raise ArgumentError.new('number of threads must be greater than zero') if num_threads < 1
        raise ArgumentError.new("#{@overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.keys.include?(@overflow_policy)

        @executor = java.util.concurrent.Executors.newFixedThreadPool(num_threads)
        @executor.setRejectedExecutionHandler(OVERFLOW_POLICIES[@overflow_policy].new)

        # without this the process may fail to exit
        at_exit { self.kill }
      end
    end
  end
end
