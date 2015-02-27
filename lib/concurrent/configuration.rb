require 'thread'
require 'concurrent/delay'
require 'concurrent/errors'
require 'concurrent/atomics'
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

    # Create a new configuration object.
    def initialize
      @global_task_pool      = Delay.new(executor: :immediate) { new_task_pool }
      @global_operation_pool = Delay.new(executor: :immediate) { new_operation_pool }
      @global_timer_set      = Delay.new(executor: :immediate) { Concurrent::TimerSet.new }
      @logger                = no_logger
      @auto_terminate        = Concurrent::AtomicBoolean.new(true)
    end

    # defines if executors should be auto-terminated in at_exit callback
    def auto_terminate=(value)
      @auto_terminate.value = value
    end

    # defines if executors should be auto-terminated in at_exit callback
    def auto_terminate
      @auto_terminate.value
    end
    alias :auto_terminate? :auto_terminate

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
      warn '[DEPRECATED] Replacing global thread pools is deprecated. Use the :executor constructor option instead.'
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
      warn '[DEPRECATED] Replacing global thread pools is deprecated. Use the :executor constructor option instead.'
      @global_operation_pool.reconfigure { executor } or
        raise ConfigurationError.new('global operation pool was already set')
    end

    def new_task_pool
      Concurrent::ThreadPoolExecutor.new(
        stop_on_exit:    true,
        min_threads:     [2, Concurrent.processor_count].max,
        max_threads:     [20, Concurrent.processor_count * 15].max,
        idletime:        2 * 60, # 2 minutes
        max_queue:       0, # unlimited
        fallback_policy: :abort # raise an exception
      )
    end

    def new_operation_pool
      Concurrent::ThreadPoolExecutor.new(
        stop_on_exit:    true,
        min_threads:     [2, Concurrent.processor_count].max,
        max_threads:     [2, Concurrent.processor_count].max,
        idletime:        10 * 60, # 10 minutes
        max_queue:       [20, Concurrent.processor_count * 15].max,
        fallback_policy: :abort # raise an exception
      )
    end
  end

  # create the default configuration on load
  @configuration = Atomic.new(Configuration.new)

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

  # set exit hook to shutdown global thread pools
  at_exit do
    if Concurrent::Configuration.configuration.auto_terminate?
      [
        Concurrent::Configuration.configuration.global_timer_set,
        Concurrent::Configuration.configuration.global_task_pool,
        Concurrent::Configuration.configuration.global_operation_pool
      ].each do |pool|
        # kill the thread pool unless it has its own at_exit handler
        pool.kill unless pool.auto_terminate?
      end
    end
  end
end
