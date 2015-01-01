require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  # @!macro cached_thread_pool
  class RubyCachedThreadPool < RubyThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Hash] opts the options defining pool behavior.
    # @option opts [Symbol] :fallback_policy (`:abort`) the fallback policy
    #
    # @raise [ArgumentError] if `fallback_policy` is not a known policy
    def initialize(opts = {})
      fallback_policy = opts.fetch(:fallback_policy, opts.fetch(:overflow_policy, :abort))

      raise ArgumentError.new("#{fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICIES.include?(fallback_policy)

      opts = opts.merge(
        min_threads: 0,
        max_threads: DEFAULT_MAX_POOL_SIZE,
        fallback_policy: fallback_policy,
        max_queue: DEFAULT_MAX_QUEUE_SIZE,
        idletime: DEFAULT_THREAD_IDLETIMEOUT
      )
      super(opts)
    end
  end
end
