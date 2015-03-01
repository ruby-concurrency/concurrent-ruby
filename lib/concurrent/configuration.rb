require 'thread'
require 'concurrent/lazy_reference'
require 'concurrent/atomics'
require 'concurrent/errors'
require 'concurrent/executors'
require 'concurrent/utility/processor_count'

module Concurrent
  extend Logging

  # initialize the global executors
  class << self

    # @!visibility private
    @@auto_terminate_global_executors = Concurrent::AtomicBoolean.new(true)

    # @!visibility private
    @@auto_terminate_all_executors = Concurrent::AtomicBoolean.new(true)

    # @!visibility private
    @@global_fast_executor = LazyReference.new do
      Concurrent.new_fast_executor(
        stop_on_exit: @@auto_terminate_global_executors.value)
    end

    # @!visibility private
    @@global_io_executor = LazyReference.new do
      Concurrent.new_io_executor(
        stop_on_exit: @@auto_terminate_global_executors.value)
    end

    # @!visibility private
    @@global_timer_set = LazyReference.new do
      Concurrent::TimerSet.new(
        stop_on_exit: @@auto_terminate_global_executors.value)
    end
  end

  # Defines if global executors should be auto-terminated with an
  # `at_exit` callback. When set to `false` it will be the application
  # programmer's responsibility to ensure that the global thread pools
  # are shutdown properly prior to application exit.
  #
  # @note Only change this option if you know what you are doing!
  #   When this is set to true (the default) then `at_exit` handlers
  #   will be registered automatically for the *global* thread pools
  #   to ensure that they are shutdown when the application ends. When
  #   changed to false, the `at_exit` handlers will be circumvented
  #   for all *global* thread pools. This method should *never* be called
  #   from within a gem. It should *only* be used from within the main
  #   application and even then it should be used only when necessary.
  #
  def self.disable_auto_termination_of_global_executors!
    @@auto_terminate_global_executors.make_false
  end

  # Defines if global executors should be auto-terminated with an
  # `at_exit` callback. When set to `false` it will be the application
  # programmer's responsibility to ensure that the global thread pools
  # are shutdown properly prior to application exit.
  #
  # @note Only change this option if you know what you are doing!
  #   When this is set to true (the default) then `at_exit` handlers
  #   will be registered automatically for the *global* thread pools
  #   to ensure that they are shutdown when the application ends. When
  #   changed to false, the `at_exit` handlers will be circumvented
  #   for all *global* thread pools. This method should *never* be called
  #   from within a gem. It should *only* be used from within the main
  #   application and even then it should be used only when necessary.
  #
  # @return [Boolean] true when global thread pools will auto-terminate on
  #   application exit using an `at_exit` handler; false when no auto-termination
  #   will occur.
  def self.auto_terminate_global_executors?
    @@auto_terminate_global_executors.value
  end

  # Defines if *ALL* executors should be auto-terminated with an
  # `at_exit` callback. When set to `false` it will be the application
  # programmer's responsibility to ensure that *all* thread pools,
  # including the global thread pools, are shutdown properly prior to
  # application exit.
  #
  # @note Only change this option if you know what you are doing!
  #   When this is set to true (the default) then `at_exit` handlers
  #   will be registered automatically for *all* thread pools to
  #   ensure that they are shutdown when the application ends. When
  #   changed to false, the `at_exit` handlers will be circumvented
  #   for *all* Concurrent Ruby thread pools running within the
  #   application. Even those created within other gems used by the
  #   application. This method should *never* be called from within a
  #   gem. It should *only* be used from within the main application.
  #   And even then it should be used only when necessary.
  def self.disable_auto_termination_of_all_executors!
    @@auto_terminate_all_executors.make_false
  end

  # Defines if *ALL* executors should be auto-terminated with an
  # `at_exit` callback. When set to `false` it will be the application
  # programmer's responsibility to ensure that *all* thread pools,
  # including the global thread pools, are shutdown properly prior to
  # application exit.
  #
  # @note Only change this option if you know what you are doing!
  #   When this is set to true (the default) then `at_exit` handlers
  #   will be registered automatically for *all* thread pools to
  #   ensure that they are shutdown when the application ends. When
  #   changed to false, the `at_exit` handlers will be circumvented
  #   for *all* Concurrent Ruby thread pools running within the
  #   application. Even those created within other gems used by the
  #   application. This method should *never* be called from within a
  #   gem. It should *only* be used from within the main application.
  #   And even then it should be used only when necessary.
  #
  # @return [Boolean] true when *all* thread pools will auto-terminate on
  #   application exit using an `at_exit` handler; false when no auto-termination
  #   will occur.
  def self.auto_terminate_all_executors?
    @@auto_terminate_all_executors.value
  end

  # Global thread pool optimized for short, fast *operations*.
  #
  # @return [ThreadPoolExecutor] the thread pool
  def self.global_fast_executor
    @@global_fast_executor.value
  end

  # Global thread pool optimized for long, blocking (IO) *tasks*.
  #
  # @return [ThreadPoolExecutor] the thread pool
  def self.global_io_executor
    @@global_io_executor.value
  end

  # Global thread pool user for global *timers*.
  #
  # @return [Concurrent::TimerSet] the thread pool
  #
  # @see Concurrent::timer
  def self.global_timer_set
    @@global_timer_set.value
  end

  def self.shutdown_global_executors
    global_fast_executor.shutdown
    global_io_executor.shutdown
    global_timer_set.shutdown
  end

  def self.kill_global_executors
    global_fast_executor.kill
    global_io_executor.kill
    global_timer_set.kill
  end

  def self.wait_for_global_executors_termination(timeout = nil)
    latch = Concurrent::CountDownLatch.new(3)
    [ global_fast_executor, global_io_executor, global_timer_set ].each do |executor|
      Thread.new{ executor.wait_for_termination(timeout); latch.count_down }
    end
    latch.wait(timeout)
  end

  def self.new_fast_executor(opts = {})
    Concurrent::FixedThreadPool.new(
      [2, Concurrent.processor_count].max,
      stop_on_exit:    opts.fetch(:stop_on_exit, true),
      idletime:        60,          # 1 minute
      max_queue:       0,           # unlimited
      fallback_policy: :caller_runs # shouldn't matter -- 0 max queue
    )
  end

  def self.new_io_executor(opts = {})
    Concurrent::ThreadPoolExecutor.new(
      min_threads: [2, Concurrent.processor_count].max,
      max_threads: Concurrent.processor_count * 100,
      stop_on_exit:    opts.fetch(:stop_on_exit, true),
      idletime:        60,          # 1 minute
      max_queue:       0,           # unlimited
      fallback_policy: :caller_runs # shouldn't matter -- 0 max queue
    )
  end

  # A gem-level configuration object.
  class Configuration

    # a proc defining how to log messages, its interface has to be:
    #   lambda { |level, progname, message = nil, &block| _ }
    attr_accessor :logger

    # Create a new configuration object.
    def initialize
      @logger                = no_logger
    end

    # if assigned to {#logger}, it will log nothing.
    def no_logger
      lambda { |level, progname, message = nil, &block| }
    end

    # @deprecated Use Concurrent.global_io_executor instead
    def global_task_pool
      warn '[DEPRECATED] Use Concurrent.global_io_executor instead'
      Concurrent.global_io_executor
    end

    # @deprecated Use Concurrent.global_fast_executor instead
    def global_operation_pool
      warn '[DEPRECATED] Use Concurrent.global_fast_executor instead'
      Concurrent.global_fast_executor
    end

    # @deprecated Use Concurrent.global_timer_set instead
    def global_timer_set
      warn '[DEPRECATED] Use Concurrent.global_timer_set instead'
      Concurrent.global_timer_set
    end

    # @deprecated Replacing global thread pools is deprecated.
    #   Use the :executor constructor option instead.
    def global_task_pool=(executor)
      warn '[DEPRECATED] Replacing global thread pools is deprecated. Use the :executor constructor option instead.'
      var = Concurrent.class_variable_get(:@@global_io_executor)
      var.reconfigure { executor } or
        raise ConfigurationError.new('global task pool was already set')
    end

    # @deprecated Replacing global thread pools is deprecated.
    #   Use the :executor constructor option instead.
    def global_operation_pool=(executor)
      warn '[DEPRECATED] Replacing global thread pools is deprecated. Use the :executor constructor option instead.'
      var = Concurrent.class_variable_get(:@@global_fast_executor)
      var.reconfigure { executor } or
        raise ConfigurationError.new('global operation pool was already set')
    end

    # @deprecated Use Concurrent.new_io_executor instead
    def new_task_pool
      warn '[DEPRECATED] Use Concurrent.new_io_executor instead'
      Concurrent.new_io_executor
    end

    # @deprecated Use Concurrent.new_fast_executor instead
    def new_operation_pool
      warn '[DEPRECATED] Use Concurrent.new_fast_executor instead'
      Concurrent.new_fast_executor
    end

    # @deprecated Use Concurrent.disable_auto_termination_of_global_executors! instead
    def auto_terminate=(value)
      warn '[DEPRECATED] Use Concurrent.disable_auto_termination_of_global_executors! instead'
      Concurrent.disable_auto_termination_of_global_executors! if !value
    end

    # @deprecated Use Concurrent.auto_terminate_global_executors? instead
    def auto_terminate
      warn '[DEPRECATED] Use Concurrent.auto_terminate_global_executors? instead'
      Concurrent.auto_terminate_global_executors?
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
end
