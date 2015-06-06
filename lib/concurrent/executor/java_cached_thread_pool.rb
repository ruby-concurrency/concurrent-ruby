if Concurrent.on_jruby?

  require 'concurrent/executor/java_thread_pool_executor'

  module Concurrent

    # @!macro cached_thread_pool
    # @!macro thread_pool_options
    class JavaCachedThreadPool < JavaThreadPoolExecutor

      # Create a new thread pool.
      #
      # @param [Hash] opts the options defining pool behavior.
      # @option opts [Symbol] :fallback_policy (`:abort`) the fallback policy
      #
      # @raise [ArgumentError] if `fallback_policy` is not a known policy
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newCachedThreadPool--
      def initialize(opts = {})
        defaults  = { idletime: DEFAULT_THREAD_IDLETIMEOUT }
        overrides = { min_threads:     0,
                      max_threads:     DEFAULT_MAX_POOL_SIZE,
                      max_queue:       0 }
        super(defaults.merge(opts).merge(overrides))
      end

      protected

      def ns_initialize(opts)
        super(opts)
        @max_queue = 0
        @executor = java.util.concurrent.Executors.newCachedThreadPool
        @executor.setRejectedExecutionHandler(FALLBACK_POLICY_CLASSES[@fallback_policy].new)
        @executor.setKeepAliveTime(opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT), java.util.concurrent.TimeUnit::SECONDS)
        self.auto_terminate = opts.fetch(:auto_terminate, true)
      end
    end
  end
end
