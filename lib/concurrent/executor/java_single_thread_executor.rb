if Concurrent.on_jruby?

  require 'concurrent/executor/java_executor_service'
  require 'concurrent/executor/serial_executor_service'

  module Concurrent

    # @!macro single_thread_executor
    # @!macro thread_pool_options
    # @!macro abstract_executor_service_public_api
    # @!visibility private
    class JavaSingleThreadExecutor < JavaExecutorService
      include SerialExecutorService

      # @!macro single_thread_executor_method_initialize
      def initialize(opts = {})
        super(opts)
      end

      # @!macro executor_service_method_prioritized_question
      def prioritized?
        @prioritized
      end

      # @!method prioritize(priority, *args, &task)
      #   @!macro executor_service_method_prioritize
      public :prioritize

      private

      def ns_initialize(opts)

        @fallback_policy = opts.fetch(:fallback_policy, :discard)
        raise ArgumentError.new("#{@fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICY_CLASSES.keys.include?(@fallback_policy)

        @prioritized = opts.fetch(:prioritize, false)

        if @prioritized
          queue = java.util.concurrent.PriorityBlockingQueue.new
          @executor = java.util.concurrent.ThreadPoolExecutor.new(
            1, 1,
            java.lang.Long::MAX_VALUE, java.util.concurrent.TimeUnit::NANOSECONDS,
            queue, FALLBACK_POLICY_CLASSES[@fallback_policy].new)
        else
          @executor = java.util.concurrent.Executors.newSingleThreadExecutor
        end

        self.auto_terminate = opts.fetch(:auto_terminate, true)
      end
    end
  end
end
