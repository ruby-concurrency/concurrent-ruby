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
        super(opts)
      end

      protected

      def ns_initialize(opts)
        @fallback_policy = opts.fetch(:fallback_policy, opts.fetch(:overflow_policy, :abort))
        deprecated ':overflow_policy is deprecated terminology, please use :fallback_policy instead' if opts.has_key?(:overflow_policy)
        @max_queue = 0

        raise ArgumentError.new("#{@fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICY_CLASSES.keys.include?(@fallback_policy)

        @executor = java.util.concurrent.Executors.newCachedThreadPool
        @executor.setRejectedExecutionHandler(FALLBACK_POLICY_CLASSES[@fallback_policy].new)
        @executor.setKeepAliveTime(opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT), java.util.concurrent.TimeUnit::SECONDS)

        self.auto_terminate = opts.fetch(:auto_terminate, true)
      end
    end
  end
end
