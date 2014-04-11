require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  # @!macro fixed_thread_pool
  class RubyFixedThreadPool < RubyThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Integer] num_threads the number of threads to allocate
    # @param [Hash] opts the options defining pool behavior.
    # @option opts [Symbol] :overflow_policy (`:abort`) the overflow policy
    #
    # @raise [ArgumentError] if `num_threads` is less than or equal to zero
    # @raise [ArgumentError] if `overflow_policy` is not a known policy
    def initialize(num_threads, opts = {})
      overflow_policy = opts.fetch(:overflow_policy, :abort)

      raise ArgumentError.new('number of threads must be greater than zero') if num_threads < 1
      raise ArgumentError.new("#{overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.include?(overflow_policy)

      opts = opts.merge(
        min_threads: num_threads,
        max_threads: num_threads,
        num_threads: overflow_policy,
        max_queue: DEFAULT_MAX_QUEUE_SIZE,
        idletime: 0
      )
      super(opts)
    end
  end
end
