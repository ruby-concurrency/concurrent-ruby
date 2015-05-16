if Concurrent.on_jruby?
  require 'concurrent/executor/executor_service'

  module Concurrent

    # @!macro single_thread_executor
    # @!macro thread_pool_options
    class JavaSingleThreadExecutor < JavaExecutorService
      include SerialExecutorService

      # Create a new thread pool.
      #
      # @option opts [Symbol] :fallback_policy (:discard) the policy
      #   for handling new tasks that are received when the queue size
      #   has reached `max_queue` or after the executor has shut down
      #
      # @see http://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html
      # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Executors.html
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ExecutorService.html
      def initialize(opts = {})
        super(opts)
      end

      protected
      
      def ns_initialize(opts)
        @executor = java.util.concurrent.Executors.newSingleThreadExecutor
        @fallback_policy = opts.fetch(:fallback_policy, :discard)
        raise ArgumentError.new("#{@fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICY_CLASSES.keys.include?(@fallback_policy)
        self.auto_terminate = opts.fetch(:auto_terminate, true)
      end
    end
  end
end
