if RUBY_PLATFORM == 'java'
  require_relative 'executor'

  module Concurrent

    # @!macro single_thread_executor
    class JavaSingleThreadExecutor
      include JavaExecutor
      include SerialExecutor

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
        @executor = java.util.concurrent.Executors.newSingleThreadExecutor
        @fallback_policy = opts.fetch(:fallback_policy, :discard)
        raise ArgumentError.new("#{@fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICIES.keys.include?(@fallback_policy)
        set_shutdown_hook
      end
    end
  end
end
