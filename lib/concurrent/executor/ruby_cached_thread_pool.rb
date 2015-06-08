require 'concurrent/executor/ruby_thread_pool_executor'

module Concurrent

  # @!macro cached_thread_pool
  # @!macro thread_pool_options
  # @!macro thread_pool_executor_public_api
  # @!visibility private
  class RubyCachedThreadPool < RubyThreadPoolExecutor

    # @!macro cached_thread_pool_method_initialize
    def initialize(opts = {})
      defaults  = { idletime: DEFAULT_THREAD_IDLETIMEOUT }
      overrides = { min_threads:     0,
                    max_threads:     DEFAULT_MAX_POOL_SIZE,
                    max_queue:       DEFAULT_MAX_QUEUE_SIZE }
      super(defaults.merge(opts).merge(overrides))
    end
  end
end
