require 'concurrent/ruby_thread_pool_executor'

module Concurrent

  # @!macro fixed_thread_pool
  class RubyFixedThreadPool < RubyThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Integer] num_threads the number of threads to allocate
    #
    # @raise [ArgumentError] if +num_threads+ is less than or equal to zero
    def initialize(num_threads, opts = {})
      raise ArgumentError.new('number of threads must be greater than zero') if num_threads < 1
      opts = opts.merge(
        min_threads: num_threads,
        max_threads: num_threads,
        idletime: 0
      )
      super(opts)
    end
  end
end
