require 'thread'
require 'concurrent/delay'
require 'concurrent/executor/thread_pool_executor'
require 'concurrent/executor/timer_set'
require 'concurrent/utility/processor_count'

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
      configuration.global_timer_set
    end
  end

  # A gem-level configuration object.
  class Configuration

    # Create a new configuration object.
    def initialize
      @cores = Concurrent::processor_count

      @global_task_pool = Delay.new do
        Concurrent::ThreadPoolExecutor.new(
            min_threads:     [2, @cores].max,
            max_threads:     [20, @cores * 15].max,
            idletime:        2 * 60, # 2 minutes
            max_queue:       0, # unlimited
            overflow_policy: :abort # raise an exception
        )
      end

      @global_operation_pool = Delay.new do
        Concurrent::ThreadPoolExecutor.new(
            min_threads:     [2, @cores].max,
            max_threads:     [2, @cores].max,
            idletime:        10 * 60, # 10 minutes
            max_queue:       [20, @cores * 15].max,
            overflow_policy: :abort # raise an exception
        )
      end

      @global_timer_set = Delay.new { Concurrent::TimerSet.new }
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
    # @raise [ConfigurationError] if this thread pool has already been set
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
    # @raise [ConfigurationError] if this thread pool has already been set
    def global_operation_pool=(executor)
      @global_operation_pool.reconfigure { executor } or
          raise ConfigurationError.new('global operation pool was already set')
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
  rescue => ex
    puts "#{ex.message} (#{ex.class})\n#{ex.backtrace.join("\n")}"
    false
  end

  # create the default configuration on load
  self.configuration = Configuration.new

  # set exit hook to shutdown global thread pools
  at_exit do
    # self.finalize_executor(self.configuration.global_timer_set)
    # self.finalize_executor(self.configuration.global_task_pool)
    # self.finalize_executor(self.configuration.global_operation_pool)
  end
end
