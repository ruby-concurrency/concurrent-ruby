require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  # @!macro fixed_thread_pool
  # @!macro thread_pool_options
  # @!macro thread_pool_executor_public_api
  # @!visibility private
  class RubyFixedThreadPool < RubyThreadPoolExecutor

    # @!macro fixed_thread_pool_method_initialize
    def initialize(num_threads, opts = {})
      raise ArgumentError.new('number of threads must be greater than zero') if num_threads.to_i < 1
      defaults  = { max_queue:   DEFAULT_MAX_QUEUE_SIZE,
                    idletime:    DEFAULT_THREAD_IDLETIMEOUT }
      overrides = { min_threads: num_threads,
                    max_threads: num_threads }
      super(defaults.merge(opts).merge(overrides))
    end
  end
end
