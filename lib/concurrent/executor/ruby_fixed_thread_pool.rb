require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  # @!macro fixed_thread_pool
  class RubyFixedThreadPool < RubyThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Integer] num_threads the number of threads to allocate
    # @param [Hash] opts the options defining pool behavior.
    # @option opts [Symbol] :fallback_policy (`:abort`) the fallback policy
    #
    # @raise [ArgumentError] if `num_threads` is less than or equal to zero
    # @raise [ArgumentError] if `fallback_policy` is not a known policy
    def initialize(num_threads, opts = {})
      fallback_policy = opts.fetch(:fallback_policy, opts.fetch(:overflow_policy, :abort))

      raise ArgumentError.new('number of threads must be greater than zero') if num_threads < 1
      raise ArgumentError.new("#{fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICIES.include?(fallback_policy)

      opts = {
        min_threads: num_threads,
        max_threads: num_threads,
        fallback_policy: fallback_policy,
        max_queue: DEFAULT_MAX_QUEUE_SIZE,
        idletime: DEFAULT_THREAD_IDLETIMEOUT,
      }.merge(opts)
      super(opts)
    end
  end
end
