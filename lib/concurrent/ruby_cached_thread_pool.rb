require 'concurrent/ruby_thread_pool_executor'

module Concurrent

  # @!macro cached_thread_pool
  class RubyCachedThreadPool < RubyThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Hash] opts the options defining pool behavior.
    #   number of seconds a thread may be idle before it is reclaimed
    #
    # @raise [ArgumentError] if `overflow_policy` is not a known policy
    def initialize(opts = {})
      overflow_policy = opts.fetch(:overflow_policy, :abort)

      raise ArgumentError.new("#{overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.include?(overflow_policy)

      opts = opts.merge(
        min_threads: 0,
        max_threads: DEFAULT_MAX_POOL_SIZE,
        num_threads: overflow_policy,
        max_queue: DEFAULT_MAX_QUEUE_SIZE,
        idletime: DEFAULT_THREAD_IDLETIMEOUT
      )
      super(opts)
    end
  end
end
