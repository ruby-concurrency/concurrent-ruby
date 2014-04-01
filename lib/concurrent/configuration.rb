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
    attr_accessor :global_task_pool
    attr_accessor :global_operation_pool

    def initialize
      task_pool_config = {
        min_threads: [2, cores].max,
        max_threads: [20, cores * 15].max,
        idletime: 2 * 60,                  # 2 minutes
        max_queue: 0,                      # unlimited
        overflow_policy: :abort            # raise an exception
      }

      operation_pool_config = {
        min_threads: [2, cores].max,
        max_threads: [2, cores].max,
        idletime: 10 * 60,                 # 10 minutes
        max_queue: [20, cores * 15].max,
        overflow_policy: :abort            # raise an exception
      }

      @global_task_pool = Concurrent::ThreadPoolExecutor.new(task_pool_config)
      @global_operation_pool = Concurrent::ThreadPoolExecutor.new(operation_pool_config)
    end

    def cores
      @cores ||= Concurrent::processor_count
    end

    def global_task_pool=(executor)
      finalize_executor(@global_task_pool)
      @global_task_pool = executor
    end

    def global_operation_pool=(executor)
      finalize_executor(@global_operation_pool)
      @global_operation_pool = executor
    end

    private

    def finalize_executor(executor)
      return if executor.nil?
      if executor.respond_to?(:shutdown)
        executor.shutdown
      elsif executor.respond_to?(:kill)
        executor.kill
      end
    rescue
      # suppress
    end
  end

  module OptionsParser

    def get_executor_from(opts = {})
      if opts.has_key?(:executor)
        opts[:executor]
      elsif opts[:operation] == true || opts[:task] == false
        Concurrent.configuration.global_operation_pool
      else
        Concurrent.configuration.global_task_pool
      end
    end
  end

  def task(*args, &block)
    Concurrent.configuration.global_task_pool.post(*args, &block)
  end
  module_function :task

  def operation(*args, &block)
    Concurrent.configuration.global_operation_pool.post(*args, &block)
  end
  module_function :operation

  # create the default configuration on load
  self.configuration = Configuration.new

  # set exit hook to shutdown global thread pools
  at_exit do
    self.configuration.global_task_pool = nil
    self.configuration.global_operation_pool = nil
  end
end
