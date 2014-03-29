require 'concurrent/per_thread_executor'

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
      @global_thread_pool = Concurrent::PerThreadExecutor.new
    end
  end

  # create the default configuration on load
  self.configuration = Configuration.new
end
