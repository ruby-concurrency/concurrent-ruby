if RUBY_PLATFORM == 'java'

  require 'concurrent/java_thread_pool_executor'

  module Concurrent

    # @!macro cached_thread_pool
    class JavaCachedThreadPool < JavaThreadPoolExecutor

      # Create a new thread pool.
      #
      # @param [Hash] opts the options defining pool behavior.
      # @option opts [Integer] :max_threads (+DEFAULT_MAX_POOL_SIZE+) maximum number
      #   of threads which may be created in the pool
      # @option opts [Integer] :idletime (+DEFAULT_THREAD_IDLETIMEOUT+) maximum
      #   number of seconds a thread may be idle before it is reclaimed
      # @option opts [Symbol] :overflow_policy (+:abort+) the overflow policy
      #
      # @raise [ArgumentError] if +max_threads+ is less than or equal to zero
      # @raise [ArgumentError] if +idletime+ is less than or equal to zero
      # @raise [ArgumentError] if +overflow_policy+ is not a known policy
      #
      # @see http://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html#newCachedThreadPool--
      def initialize(opts = {})
        max_length = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
        idletime = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
        @overflow_policy = opts.fetch(:overflow_policy, :abort)
        @max_queue = 0

        raise ArgumentError.new('idletime must be greater than zero') if idletime <= 0
        raise ArgumentError.new('max_threads must be greater than zero') if max_length <= 0
        raise ArgumentError.new("#{@overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.keys.include?(@overflow_policy)

        @executor = java.util.concurrent.ThreadPoolExecutor.new(
          @max_queue, max_length,
          idletime, java.util.concurrent.TimeUnit::SECONDS,
          java.util.concurrent.SynchronousQueue.new,
          OVERFLOW_POLICIES[@overflow_policy].new)

        # without this the process may fail to exit
        at_exit { self.kill }
      end
    end
  end
end
