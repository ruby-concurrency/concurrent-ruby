require 'thread'
require 'concurrent/thread_pool_executor'
require 'concurrent/processor_count'

module Concurrent

  ConfigurationError = Class.new(StandardError)

  class << self
    attr_accessor :configuration
  end

  def self.configure
    (@mutex ||= Mutex.new).synchronize do
      yield(configuration)
    end
  end

  class Configuration
    attr_accessor :global_task_pool
    attr_accessor :global_operation_pool

    def initialize
      @cores ||= Concurrent::processor_count
    end

    def global_task_pool
      @global_task_pool ||= Concurrent::ThreadPoolExecutor.new(
        min_threads: [2, @cores].max,
        max_threads: [20, @cores * 15].max,
        idletime: 2 * 60,                   # 2 minutes
        max_queue: 0,                       # unlimited
        overflow_policy: :abort             # raise an exception
      )
    end

    def global_operation_pool
      @global_operation_pool ||= Concurrent::ThreadPoolExecutor.new(
        min_threads: [2, @cores].max,
        max_threads: [2, @cores].max,
        idletime: 10 * 60,                  # 10 minutes
        max_queue: [20, @cores * 15].max,
        overflow_policy: :abort             # raise an exception
      )
    end

    def global_task_pool=(executor)
      raise ConfigurationError.new('global task pool was already set') unless @global_task_pool.nil?
      @global_task_pool = executor
    end

    def global_operation_pool=(executor)
      raise ConfigurationError.new('global operation pool was already set') unless @global_operation_pool.nil?
      @global_operation_pool = executor
    end
  end

  module OptionsParser

    def get_executor_from(opts = {})
      if opts[:executor]
        opts[:executor]
      elsif opts[:operation] == true || opts[:task] == false
        Concurrent.configuration.global_operation_pool
      else
        Concurrent.configuration.global_task_pool
      end
    end
  end

  private

  def self.finalize_executor(executor)
    return if executor.nil?
    if executor.respond_to?(:shutdown)
      executor.shutdown
    elsif executor.respond_to?(:kill)
      executor.kill
    end
  rescue
    # suppress
  end

  # create the default configuration on load
  self.configuration = Configuration.new

  # set exit hook to shutdown global thread pools
  at_exit do
    self.finalize_executor(self.configuration.global_task_pool)
    self.finalize_executor(self.configuration.global_operation_pool)
  end
end
