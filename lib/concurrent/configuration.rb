require 'thread'
require 'concurrent/delay'
require 'concurrent/errors'
require 'concurrent/atomic'
require 'concurrent/executor/immediate_executor'
require 'concurrent/executor/thread_pool_executor'
require 'concurrent/executor/timer_set'
require 'concurrent/utility/processor_count'

module Concurrent
  extend Logging

  # A gem-level configuration object.
  class Configuration

    # a proc defining how to log messages, its interface has to be:
    #   lambda { |level, progname, message = nil, &block| _ }
    attr_accessor :logger

    # defines if executors should be auto-terminated in at_exit callback
    attr_accessor :auto_terminate

    # Create a new configuration object.
    def initialize
      immediate_executor     = ImmediateExecutor.new
      @global_task_pool      = Delay.new(executor: immediate_executor) { new_task_pool }
      @global_operation_pool = Delay.new(executor: immediate_executor) { new_operation_pool }
      @global_timer_set      = Delay.new(executor: immediate_executor) { Concurrent::TimerSet.new }
      @logger                = no_logger
      @auto_terminate        = true
    end

    # if assigned to {#logger}, it will log nothing.
    def no_logger
      lambda { |level, progname, message = nil, &block| }
    end

    # Global thread pool optimized for short *tasks*.
    #
    # @return [ThreadPoolExecutor] the thread pool
    def global_task_pool
      @global_task_pool.value
    end

    # Global thread pool optimized for long *operations*.
    #
    # @return [ThreadPoolExecutor] the thread pool
    def global_operation_pool
      @global_operation_pool.value
    end

    # Global thread pool optimized for *timers*
    #
    # @return [ThreadPoolExecutor] the thread pool
    #
    # @see Concurrent::timer
    def global_timer_set
      @global_timer_set.value
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
    # @raise [Concurrent::ConfigurationError] if this thread pool has already been set
    def global_task_pool=(executor)
      @global_task_pool.reconfigure { executor } or
          raise ConfigurationError.new('global task pool was already set')
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
    # @raise [Concurrent::ConfigurationError] if this thread pool has already been set
    def global_operation_pool=(executor)
      @global_operation_pool.reconfigure { executor } or
          raise ConfigurationError.new('global operation pool was already set')
    end

    def new_task_pool
      Concurrent::ThreadPoolExecutor.new(
          min_threads:     [2, Concurrent.processor_count].max,
          max_threads:     [20, Concurrent.processor_count * 15].max,
          idletime:        2 * 60, # 2 minutes
          max_queue:       0, # unlimited
          fallback_policy: :abort # raise an exception
      )
    end

    def new_operation_pool
      Concurrent::ThreadPoolExecutor.new(
          min_threads:     [2, Concurrent.processor_count].max,
          max_threads:     [2, Concurrent.processor_count].max,
          idletime:        10 * 60, # 10 minutes
          max_queue:       [20, Concurrent.processor_count * 15].max,
          fallback_policy: :abort # raise an exception
      )
    end
  end

  # create the default configuration on load
  @configuration = Atomic.new Configuration.new

  # @return [Configuration]
  def self.configuration
    @configuration.value
  end

  # Perform gem-level configuration.
  #
  # @yield the configuration commands
  # @yieldparam [Configuration] the current configuration object
  def self.configure
    yield(configuration)
  end

  def self.finalize_global_executors
    self.finalize_executor(self.configuration.global_timer_set)
    self.finalize_executor(self.configuration.global_task_pool)
    self.finalize_executor(self.configuration.global_operation_pool)
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
  rescue => ex
    log DEBUG, ex
    false
  end

  # set exit hook to shutdown global thread pools
  at_exit do
    finalize_global_executors if configuration.auto_terminate
  end
end
