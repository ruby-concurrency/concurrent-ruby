require 'thread'

require 'concurrent/options_parser'
require 'concurrent/ivar'
require 'concurrent/executor/safe_task_executor'

module Concurrent

  # {include:file:doc/future.md}
  #
  # @see http://ruby-doc.org/stdlib-2.1.1/libdoc/observer/rdoc/Observable.html Ruby Observable module
  # @see http://clojuredocs.org/clojure_core/clojure.core/future Clojure's future function
  # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Future.html java.util.concurrent.Future
  class Future < IVar

    # Create a new `Future` in the `:unscheduled` state.
    #
    # @yield the asynchronous operation to perform
    #
    # @param [Hash] opts the options controlling how the future will be processed
    # @option opts [Boolean] :operation (false) when `true` will execute the future on the global
    #   operation pool (for long-running operations), when `false` will execute the future on the
    #   global task pool (for short-running tasks)
    # @option opts [object] :executor when provided will run all operations on
    #   this executor rather than the global thread pool (overrides :operation)
    # @option opts [object, Array] :args zero or more arguments to be passed the task block on execution
    #
    # @option opts [String] :dup_on_deref (false) call `#dup` before returning the data
    # @option opts [String] :freeze_on_deref (false) call `#freeze` before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given `Proc` passing the internal value and
    #   returning the value returned from the proc
    #
    # @raise [ArgumentError] if no block is given
    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?
      super(IVar::NO_VALUE, opts)
      @state = :unscheduled
      @task = block
      @executor = OptionsParser::get_executor_from(opts) || Concurrent.configuration.global_operation_pool
      @args = OptionsParser::get_arguments_from(opts)
    end

    # Execute an `:unscheduled` `Future`. Immediately sets the state to `:pending` and
    # passes the block to a new thread/thread pool for eventual execution.
    # Does nothing if the `Future` is in any state other than `:unscheduled`.
    #
    # @return [Future] a reference to `self`
    #
    # @example Instance and execute in separate steps
    #   future = Concurrent::Future.new{ sleep(1); 42 }
    #   future.state #=> :unscheduled
    #   future.execute
    #   future.state #=> :pending
    #
    # @example Instance and execute in one line
    #   future = Concurrent::Future.new{ sleep(1); 42 }.execute
    #   future.state #=> :pending
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        @executor.post(@args){ work }
        self
      end
    end

    # Create a new `Future` object with the given block, execute it, and return the
    # `:pending` object.
    #
    # @yield the asynchronous operation to perform
    #
    # @param [Hash] opts the options controlling how the future will be processed
    # @option opts [Boolean] :operation (false) when `true` will execute the future on the global
    #   operation pool (for long-running operations), when `false` will execute the future on the
    #   global task pool (for short-running tasks)
    # @option opts [object] :executor when provided will run all operations on
    #   this executor rather than the global thread pool (overrides :operation)
    # @option opts [object, Array] :args zero or more arguments to be passed the task block on execution
    #
    # @option opts [String] :dup_on_deref (false) call `#dup` before returning the data
    # @option opts [String] :freeze_on_deref (false) call `#freeze` before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given `Proc` passing the internal value and
    #   returning the value returned from the proc
    #
    # @return [Future] the newly created `Future` in the `:pending` state
    #
    # @raise [ArgumentError] if no block is given
    #
    # @example
    #   future = Concurrent::Future.execute{ sleep(1); 42 }
    #   future.state #=> :pending
    def self.execute(opts = {}, &block)
      Future.new(opts, &block).execute
    end

    protected :set, :fail, :complete

    private

    # @!visibility private
    def work # :nodoc:
      success, val, reason = SafeTaskExecutor.new(@task).execute(*@args)
      complete(success, val, reason)
    end
  end
end
