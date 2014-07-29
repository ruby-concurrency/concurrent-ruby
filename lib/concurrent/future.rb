require 'thread'

require 'concurrent/options_parser'
require 'concurrent/ivar'
require 'concurrent/executor/safe_task_executor'

module Concurrent

  # A `Future` represents a promise to complete an action at some time in the future.
  # The action is atomic and permanent. The idea behind a future is to send an operation
  # for asynchronous completion, do other stuff, then return and retrieve the result
  # of the async operation at a later time.
  #
  # A `Future` has four possible states: *:unscheduled*, *:pending*, *:rejected*, or *:fulfilled*.
  # When a `Future` is created its state is set to *:unscheduled*. Once the `#execute` method is
  # called the state becomes *:pending* and will remain in that state until processing is
  # complete. A completed `Future` is either *:rejected*, indicating that an exception was
  # thrown during processing, or *:fulfilled*, indicating success. If a `Future` is *:fulfilled*
  # its `value` will be updated to reflect the result of the operation. If *:rejected* the
  # `reason` will be updated with a reference to the thrown exception. The predicate methods
  # `#unscheduled?`, `#pending?`, `#rejected?`, and `fulfilled?` can be called at any time to
  # obtain the state of the `Future`, as can the `#state` method, which returns a symbol. 
  #
  # Retrieving the value of a `Future` is done through the `#value` (alias: `#deref`) method.
  # Obtaining the value of a `Future` is a potentially blocking operation. When a `Future` is
  # *:rejected* a call to `#value` will return `nil` immediately. When a `Future` is
  # *:fulfilled* a call to `#value` will immediately return the current value. When a
  # `Future` is *:pending* a call to `#value` will block until the `Future` is either
  # *:rejected* or *:fulfilled*. A *timeout* value can be passed to `#value` to limit how
  # long the call will block. If `nil` the call will block indefinitely. If `0` the call will
  # not block. Any other integer or float value will indicate the maximum number of seconds to block.
  #
  # The `Future` class also includes the behavior of the Ruby standard library `Observable` module,
  # but does so in a thread-safe way. On fulfillment or rejection all observers will be notified
  # according to the normal `Observable` behavior. The observer callback function will be called
  # with three parameters: the `Time` of fulfillment/rejection, the final `value`, and the final
  # `reason`. Observers added after fulfillment/rejection will still be notified as normal.
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
    #
    # @since 0.5.0
    def execute
      if compare_and_set_state(:pending, :unscheduled)
        @executor.post{ work }
        self
      end
    end

    # Create a new `Future` object with the given block, execute it, and return the
    # `:pending` object.
    #
    # @yield the asynchronous operation to perform
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
    #
    # @since 0.5.0
    def self.execute(opts = {}, &block)
      Future.new(opts, &block).execute
    end

    protected :set, :fail, :complete

    private

    # @!visibility private
    def work # :nodoc:
      success, val, reason = SafeTaskExecutor.new(@task).execute
      complete(success, val, reason)
    end
  end
end
