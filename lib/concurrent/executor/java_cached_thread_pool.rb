if RUBY_PLATFORM == 'java'

  require 'concurrent/executor/java_thread_pool_executor'

  module Concurrent

    # @!macro cached_thread_pool
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
        @fallback_policy = opts.fetch(:fallback_policy, opts.fetch(:overflow_policy, :abort))
        warn '[DEPRECATED] :overflow_policy is deprecated terminology, please use :fallback_policy instead' if opts.has_key?(:overflow_policy)
        @max_queue = 0

        raise ArgumentError.new("#{@fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICIES.keys.include?(@fallback_policy)

        @executor = java.util.concurrent.Executors.newCachedThreadPool
        @executor.setRejectedExecutionHandler(FALLBACK_POLICIES[@fallback_policy].new)

        set_shutdown_hook
      end
    end
  end
end
