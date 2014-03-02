require 'thread'

require 'concurrent/global_thread_pool'
require 'concurrent/obligation'
require 'concurrent/copy_on_write_observer_set'
require 'concurrent/safe_task_executor'

module Concurrent

  # A +Future+ represents a promise to complete an action at some time in the future.
  # The action is atomic and permanent. The idea behind a future is to send an operation
  # for asynchronous completion, do other stuff, then return and retrieve the result
  # of the async operation at a later time.
  #
  # A +Future+ has four possible states: *:unscheduled*, *:pending*, *:rejected*, or *:fulfilled*.
  # When a +Future+ is created its state is set to *:unscheduled*. Once the +#execute+ method is
  # called the state becomes *:pending* and will remain in that state until processing is
  # complete. A completed +Future+ is either *:rejected*, indicating that an exception was
  # thrown during processing, or *:fulfilled*, indicating success. If a +Future+ is *:fulfilled*
  # its +value+ will be updated to reflect the result of the operation. If *:rejected* the
  # +reason+ will be updated with a reference to the thrown exception. The predicate methods
  # +#unscheduled?+, +#pending?+, +#rejected?+, and +fulfilled?+ can be called at any time to
  # obtain the state of the +Future+, as can the +#state+ method, which returns a symbol. 
  #
  # Retrieving the value of a +Future+ is done through the +#value+ (alias: +#deref+) method.
  # Obtaining the value of a +Future+ is a potentially blocking operation. When a +Future+ is
  # *:rejected* a call to +#value+ will return +nil+ immediately. When a +Future+ is
  # *:fulfilled* a call to +#value+ will immediately return the current value. When a
  # +Future+ is *:pending* a call to +#value+ will block until the +Future+ is either
  # *:rejected* or *:fulfilled*. A *timeout* value can be passed to +#value+ to limit how
  # long the call will block. If +nil+ the call will block indefinitely. If +0+ the call will
  # not block. Any other integer or float value will indicate the maximum number of seconds to block.
  #
  # The +Future+ class also includes the behavior of the Ruby standard library +Observable+ module,
  # but does so in a thread-safe way. On fulfillment or rejection all observers will be notified
  # according to the normal +Observable+ behavior. The observer callback function will be called
  # with three parameters: the +Time+ of fulfillment/rejection, the final +value+, and the final
  # +reason+. Observers added after fulfillment/rejection will still be notified as normal.
  #
  # @see http://ruby-doc.org/stdlib-2.1.1/libdoc/observer/rdoc/Observable.html Ruby Observable module
  # @see http://clojuredocs.org/clojure_core/clojure.core/future Clojure's future function
  # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Future.html java.util.concurrent.Future
  class Future
    include Obligation
    include UsesGlobalThreadPool

    # Create a new +Future+ in the +:unscheduled+ state.
    #
    # @yield the asynchronous operation to perform
    #
    # @option opts [String] :dup_on_deref (false) call +#dup+ before returning the data
    # @option opts [String] :freeze_on_deref (false) call +#freeze+ before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given +Proc+ passing the internal value and
    #   returning the value returned from the proc
    #
    # @raise [ArgumentError] if no block is given
    def initialize(opts = {}, &block)
      raise ArgumentError.new('no block given') unless block_given?

      init_obligation
      @observers = CopyOnWriteObserverSet.new
      @state = :unscheduled
      @task = block
      set_deref_options(opts)
    end

    # Add +observer+ as an observer on this object so that it will receive notifications.
    #
    # Upon completion the +Future+ will notify all observers in a thread-say way. The +func+
    # method of the observer will be called with three arguments: the +Time+ at which the
    # +Future+ completed the asynchronous operation, the final +value+ (or +nil+ on rejection),
    # and the final +reason+ (or +nil+ on fulfillment).
    #
    # @param [Object] observer the object that will be notified of changes
    # @param [Symbol] func symbol naming the method to call when this +Observable+ has changes
    def add_observer(observer, func = :update)
      direct_notification = false
      mutex.synchronize do
        if event.set?
          direct_notification = true
        else
          @observers.add_observer(observer, func)
        end
      end

      observer.send(func, Time.now, self.value, reason) if direct_notification
      func
    end

    # Execute an +:unscheduled+ +Future+. Immediately sets the state to +:pending+ and
    # passes the block to a new thread/thread pool for eventual execution.
    # Does nothing if the +Future+ is in any state other than +:unscheduled+.
    #
    # @return [Future] a reference to +self+
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
        Future.thread_pool.post { work }
        self
      end
    end

    # @since 0.5.0
    def self.execute(opts = {}, &block)
      return Future.new(opts, &block).execute
    end

    private

    # @!visibility private
    def work # :nodoc:

      success, val, reason = SafeTaskExecutor.new(@task).execute

      mutex.synchronize do
        set_state(success, val, reason)
        event.set
      end

      @observers.notify_and_delete_observers(Time.now, self.value, reason)
    end
  end
end
