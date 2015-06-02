if Concurrent.on_jruby?

  require 'concurrent/executor/java_thread_pool_executor'

  module Concurrent

    # @!macro fixed_thread_pool
    # @!macro thread_pool_options
    # @api private
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
        raise ArgumentError.new('number of threads must be greater than zero') if num_threads.to_i < 1
        defaults  = { max_queue:   DEFAULT_MAX_QUEUE_SIZE,
                      idletime:    DEFAULT_THREAD_IDLETIMEOUT }
        overrides = { min_threads: num_threads,
                      max_threads: num_threads }
        super(defaults.merge(opts).merge(overrides))
      end
    end
  end
end
