require 'thread'

require 'concurrent/errors'
require 'concurrent/obligation'
require 'concurrent/observable'

module Concurrent

  # An `IVar` is like a future that you can assign. As a future is a value that is being computed that you can wait on, an `IVar` is a value that is waiting to be assigned, that you can wait on. `IVars` are single assignment and deterministic.
  # 
  # Then, express futures as an asynchronous computation that assigns an `IVar`. The `IVar` becomes the primitive on which [futures](Future) and [dataflow](Dataflow) are built.
  #
  # An `IVar` is a single-element container that is normally created empty, and
  # can only be set once. The I in `IVar` stands for immutable. Reading an `IVar`
  # normally blocks until it is set. It is safe to set and read an `IVar` from
  # different threads.
  #
  # If you want to have some parallel task set the value in an `IVar`, you want
  # a `Future`. If you want to create a graph of parallel tasks all executed when
  # the values they depend on are ready you want `dataflow`. `IVar` is generally
  # a low-level primitive.
  # 
  # **See Also:**
  #
  # * For the theory: Arvind, R. Nikhil, and K. Pingali. [I-Structures: Data structures for parallel computing](http://dl.acm.org/citation.cfm?id=69562). In Proceedings of Workshop on Graph Reduction, 1986.
  # * For recent application: [DataDrivenFuture in Habanero Java from Rice](http://www.cs.rice.edu/~vs3/hjlib/doc/edu/rice/hj/api/HjDataDrivenFuture.html).
  #
  # @example Create, set and get an `IVar`
  #   ivar = Concurrent::IVar.new
  #   ivar.set 14
  #   ivar.get #=> 14
  #   ivar.set 2 # would now be an error
  class IVar

    include Obligation
    include Observable

    # @!visibility private
    NO_VALUE = Object.new # :nodoc:

    # Create a new `IVar` in the `:pending` state with the (optional) initial value.
    #
    # @param [Object] value the initial value
    # @param [Hash] opts the options to create a message with
    # @option opts [String] :dup_on_deref (false) call `#dup` before returning the data
    # @option opts [String] :freeze_on_deref (false) call `#freeze` before returning the data
    # @option opts [String] :copy_on_deref (nil) call the given `Proc` passing the internal value and
    #   returning the value returned from the proc
    def initialize(value = NO_VALUE, opts = {})
      init_obligation
      self.observers = CopyOnWriteObserverSet.new
      set_deref_options(opts)

      if value == NO_VALUE
        @state = :pending
      else
        set(value)
      end
    end

    # Add an observer on this object that will receive notification on update.
    #
    # Upon completion the `IVar` will notify all observers in a thread-say way. The `func`
    # method of the observer will be called with three arguments: the `Time` at which the
    # `Future` completed the asynchronous operation, the final `value` (or `nil` on rejection),
    # and the final `reason` (or `nil` on fulfillment).
    #
    # @param [Object] observer the object that will be notified of changes
    # @param [Symbol] func symbol naming the method to call when this `Observable` has changes`
    def add_observer(observer = nil, func = :update, &block)
      raise ArgumentError.new('cannot provide both an observer and a block') if observer && block
      direct_notification = false

      if block
        observer = block
        func = :call
      end

      mutex.synchronize do
        if event.set?
          direct_notification = true
        else
          observers.add_observer(observer, func)
        end
      end

      observer.send(func, Time.now, self.value, reason) if direct_notification
      observer
    end

    # Set the `IVar` to a value and wake or notify all threads waiting on it.
    #
    # @param [Object] value the value to store in the `IVar`
    # @raise [Concurrent::MultipleAssignmentError] if the `IVar` has already been set or otherwise completed
    def set(value)
      complete(true, value, nil)
    end

    # Set the `IVar` to failed due to some error and wake or notify all threads waiting on it.
    #
    # @param [Object] reason for the failure
    # @raise [Concurrent::MultipleAssignmentError] if the `IVar` has already been set or otherwise completed
    def fail(reason = StandardError.new)
      complete(false, nil, reason)
    end

    # @!visibility private
    def complete(success, value, reason) # :nodoc:
      mutex.synchronize do
        raise MultipleAssignmentError.new('multiple assignment') if [:fulfilled, :rejected].include? @state
        set_state(success, value, reason)
        event.set
      end

      time = Time.now
      observers.notify_and_delete_observers{ [time, self.value, reason] }
      self
    end
  end
end
