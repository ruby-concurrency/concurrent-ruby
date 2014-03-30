require 'concurrent/ruby_thread_pool_executor'

module Concurrent

  # @!macro cached_thread_pool
  class RubyCachedThreadPool < RubyThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Hash] opts the options defining pool behavior.
    # @option opts [Integer] :max_threads (+DEFAULT_MAX_POOL_SIZE+) maximum number
    #   of threads which may be created in the pool
    # @option opts [Integer] :idletime (+DEFAULT_THREAD_IDLETIMEOUT+) maximum
    #   number of seconds a thread may be idle before it is reclaimed
    #
    # @raise [ArgumentError] if +max_threads+ is less than or equal to zero
    # @raise [ArgumentError] if +thread_idletime+ is less than or equal to zero
    def initialize(opts = {})
      max_length = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
      idletime = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i

      raise ArgumentError.new('idletime must be greater than zero') if idletime <= 0
      raise ArgumentError.new('max_threads must be greater than zero') if max_length <= 0

      opts = opts.merge(
        min_threads: 0,
        max_threads: max_length,
        idletime: idletime
      )
      super(opts)
    end
  end
end
