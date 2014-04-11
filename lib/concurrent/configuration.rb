require 'thread'
require 'concurrent/executor'
require 'concurrent/utilities/processor_count'

module Concurrent

  # An error class to be raised when errors occur during configuration.
  ConfigurationError = Class.new(StandardError)

  class << self
    attr_accessor :configuration
  end

  # Perform gem-level configuration.
  #
  # @yield the configuration commands
  # @yieldparam [Configuration] the current configuration object
  def self.configure
    (@mutex ||= Mutex.new).synchronize do
      yield(configuration)

      # initialize the global thread pools if necessary
      configuration.global_task_pool
      configuration.global_operation_pool
      configuration.global_timer_pool
    end
  end

  # A gem-level configuration object.
  class Configuration

    # Create a new configuration object.
    def initialize
      @cores ||= Concurrent::processor_count
    end

    # Global thread pool optimized for short *tasks*.
    #
    # @return [ThreadPoolExecutor] the thread pool
    def global_task_pool
      @global_task_pool ||= Concurrent::ThreadPoolExecutor.new(
        min_threads: [2, @cores].max,
        max_threads: [20, @cores * 15].max,
        idletime: 2 * 60,                   # 2 minutes
        max_queue: 0,                       # unlimited
        overflow_policy: :abort             # raise an exception
      )
    end

    # Global thread pool optimized for long *operations*.
    #
    # @return [ThreadPoolExecutor] the thread pool
    def global_operation_pool
      @global_operation_pool ||= Concurrent::ThreadPoolExecutor.new(
        min_threads: [2, @cores].max,
        max_threads: [2, @cores].max,
        idletime: 10 * 60,                  # 10 minutes
        max_queue: [20, @cores * 15].max,
        overflow_policy: :abort             # raise an exception
      )
    end

    # Global thread pool optimized for *timers*
    #
    # @return [ThreadPoolExecutor] the thread pool
    #
    # @see Concurrent::timer
    def global_timer_pool
      @global_timer_pool ||= Concurrent::CachedThreadPool.new
    end

    # Global thread pool optimized for short *tasks*.
    #
    # A global thread pool must be set as soon as the gem is loaded. Setting a new
    # thread pool once tasks and operations have been post can lead to unpredictable
    # results. The first time a task/operation is post a new thread pool will be
    # created using the default configuration. Once set the thread pool cannot be
    # changed. Thus, explicitly setting the thread pool must occur *before* any
    # tasks/operations are post else an exception will be raised.
    #
    # @param [Executor] executor the executor to be used for this thread pool
    #
    # @return [ThreadPoolExecutor] the new thread pool
    #
    # @raise [ConfigurationError] if this thread pool has already been set
    def global_task_pool=(executor)
      raise ConfigurationError.new('global task pool was already set') unless @global_task_pool.nil?
      @global_task_pool = executor
    end

    # Global thread pool optimized for long *operations*.
    #
    # A global thread pool must be set as soon as the gem is loaded. Setting a new
    # thread pool once tasks and operations have been post can lead to unpredictable
    # results. The first time a task/operation is post a new thread pool will be
    # created using the default configuration. Once set the thread pool cannot be
    # changed. Thus, explicitly setting the thread pool must occur *before* any
    # tasks/operations are post else an exception will be raised.
    #
    # @param [Executor] executor the executor to be used for this thread pool
    #
    # @return [ThreadPoolExecutor] the new thread pool
    #
    # @raise [ConfigurationError] if this thread pool has already been set
    def global_operation_pool=(executor)
      raise ConfigurationError.new('global operation pool was already set') unless @global_operation_pool.nil?
      @global_operation_pool = executor
    end
  end

  private

  # Attempt to properly shutdown the given executor using the `shutdown` or
  # `kill` method when available.
  #
  # @param [Executor] executor the executor to shutdown
  #
  # @return [Boolean] `true` if the executor is successfully shut down or `nil`, else `false`
  def self.finalize_executor(executor)
    return true if executor.nil?
    if executor.respond_to?(:shutdown)
      executor.shutdown
    elsif executor.respond_to?(:kill)
      executor.kill
    end
    true
  rescue
    false
  end

  # create the default configuration on load
  self.configuration = Configuration.new

  # set exit hook to shutdown global thread pools
  at_exit do
    self.finalize_executor(self.configuration.global_task_pool)
    self.finalize_executor(self.configuration.global_operation_pool)
  end
end
