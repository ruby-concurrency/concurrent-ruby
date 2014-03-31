require 'concurrent/thread_pool_executor'
require 'concurrent/processor_count'

module Concurrent
  class << self
    attr_accessor :configuration
  end

  def self.configure
    yield(configuration)
  end

  class Configuration
    attr_accessor :global_thread_pool

    def initialize
      cores = Concurrent::processor_count
      thread_pool_config = {
        min_threads: [2, cores].max,
        max_threads: [20, cores * 15].max,
        idletime: 5 * 60,       # 5 minutes
        max_queue: 0,           # unlimited
        overflow_policy: :abort # raise an exception
      }

      @global_thread_pool = Concurrent::ThreadPoolExecutor.new(thread_pool_config)
    end
  end

  # create the default configuration on load
  self.configuration = Configuration.new
end
