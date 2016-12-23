require 'concurrent/synchronization'
require 'concurrent/atomic/atomic_boolean'
require 'concurrent/atomic/atomic_fixnum'
require 'concurrent/edge/lock_free_stack'
require 'concurrent/errors'

module Concurrent


  # # Guide
  #
  # The guide is best place to start with promises, see {file:doc/promises.out.md}.
  #
  # {include:file:doc/promises-main.md}
  module Promises

    # @!macro [new] promises.param.default_executor
    #   @param [Executor, :io, :fast] default_executor Instance of an executor or a name of the
    #     global executor. Default executor propagates to chained futures unless overridden with
    #     executor parameter or changed with {AbstractEventFuture#with_default_executor}.
    #
    # @!macro [new] promises.param.executor
    #   @param [Executor, :io, :fast] executor Instance of an executor or a name of the
    #     global executor. The task is executed on it, default executor remains unchanged.
    #
    # @!macro [new] promises.param.args
    #   @param [Object] args arguments which are passed to the task when it's executed.
    #     (It might be prepended with other arguments, see the @yeild section).
    #
    # @!macro [new] promises.shortcut.on
    #   Shortcut of {#$0_on} with default `:io` executor supplied.
    #   @see #$0_on
    #
    # @!macro [new] promises.shortcut.using
    #   Shortcut of {#$0_using} with default `:io` executor supplied.
    #   @see #$0_using
    #
    # @!macro [new] promise.param.task-future
    #  @yieldreturn will become result of the returned Future.
    #     Its returned value becomes {Future#value} fulfilling it,
    #     raised exception becomes {Future#reason} rejecting it.
    #
    # @!macro [new] promise.param.callback
    #  @yieldreturn is forgotten.

    # Container of all {Future}, {Event} factory methods. They are never constructed directly with
    # new.
    module FactoryMethods

      # @!macro promises.shortcut.on
      # @return [ResolvableEvent]
      def resolvable_event
        resolvable_event_on :io
      end

      # Created resolvable event, user is responsible for resolving the event once by
      # {Promises::ResolvableEvent#resolve}.
      #
      # @!macro promises.param.default_executor
      # @return [ResolvableEvent]
      def resolvable_event_on(default_executor = :io)
        ResolvableEventPromise.new(default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [ResolvableFuture]
      def resolvable_future
        resolvable_future_on :io
      end

      # Creates resolvable future, user is responsible for resolving the future once by
      # {Promises::ResolvableFuture#resolve}, {Promises::ResolvableFuture#fulfill},
      # or {Promises::ResolvableFuture#reject}
      #
      # @!macro promises.param.default_executor
      # @return [ResolvableFuture]
      def resolvable_future_on(default_executor = :io)
        ResolvableFuturePromise.new(default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def future(*args, &task)
        future_on(:io, *args, &task)
      end

      # @!macro [new] promises.future-on1
      #   Constructs new Future which will be resolved after block is evaluated on default executor.
      # Evaluation begins immediately.
      #
      # @!macro [new] promises.future-on2
      #   @!macro promises.param.default_executor
      #   @!macro promises.param.args
      #   @yield [*args] to the task.
      #   @!macro promise.param.task-future
      #   @return [Future]
      def future_on(default_executor, *args, &task)
        ImmediateEventPromise.new(default_executor).future.then(*args, &task)
      end

      # Creates resolved future with will be either fulfilled with the given value or rejection with
      # the given reason.
      #
      # @!macro promises.param.default_executor
      # @return [Future]
      def resolved_future(fulfilled, value, reason, default_executor = :io)
        ImmediateFuturePromise.new(default_executor, fulfilled, value, reason).future
      end

      # Creates resolved future with will be fulfilled with the given value.
      #
      # @!macro promises.param.default_executor
      # @return [Future]
      def fulfilled_future(value, default_executor = :io)
        resolved_future true, value, nil, default_executor
      end

      # Creates resolved future with will be rejected with the given reason.
      #
      # @!macro promises.param.default_executor
      # @return [Future]
      def rejected_future(reason, default_executor = :io)
        resolved_future false, nil, reason, default_executor
      end

      # Creates resolved event.
      #
      # @!macro promises.param.default_executor
      # @return [Event]
      def resolved_event(default_executor = :io)
        ImmediateEventPromise.new(default_executor).event
      end

      # General constructor. Behaves differently based on the argument's type. It's provided for convenience
      # but it's better to be explicit.
      #
      # @see rejected_future, resolved_event, fulfilled_future
      # @!macro promises.param.default_executor
      # @return [Event, Future]
      #
      # @overload create(nil, default_executor = :io)
      #   @param [nil] nil
      #   @return [Event] resolved event.
      #
      # @overload create(a_future, default_executor = :io)
      #   @param [Future] a_future
      #   @return [Future] a future which will be resolved when a_future is.
      #
      # @overload create(an_event, default_executor = :io)
      #   @param [Event] an_event
      #   @return [Event] an event which will be resolved when an_event is.
      #
      # @overload create(exception, default_executor = :io)
      #   @param [Exception] exception
      #   @return [Future] a rejected future with the exception as its reason.
      #
      # @overload create(value, default_executor = :io)
      #   @param [Object] value when none of the above overloads fits
      #   @return [Future] a fulfilled future with the value.
      def create(argument = nil, default_executor = :io)
        case argument
        when AbstractEventFuture
          # returning wrapper would change nothing
          argument
        when Exception
          rejected_future argument, default_executor
        when nil
          resolved_event default_executor
        else
          fulfilled_future argument, default_executor
        end
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def delay(*args, &task)
        delay_on :io, *args, &task
      end

      # @!macro promises.future-on1
      # The task will be evaluated only after the future is touched, see {AbstractEventFuture#touch}
      #
      # @!macro promises.future-on2
      def delay_on(default_executor, *args, &task)
        DelayPromise.new(default_executor).event.chain(*args, &task)
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def schedule(intended_time, *args, &task)
        schedule_on :io, intended_time, *args, &task
      end

      # @!macro promises.future-on1
      # The task is planned for execution in intended_time.
      #
      # @!macro promises.future-on2
      # @!macro [new] promises.param.intended_time
      #   @param [Numeric, Time] intended_time `Numeric` means to run in `intended_time` seconds.
      #     `Time` means to run on `intended_time`.
      def schedule_on(default_executor, intended_time, *args, &task)
        ScheduledPromise.new(default_executor, intended_time).future.then(*args, &task)
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def zip_futures(*futures_and_or_events)
        zip_futures_on :io, *futures_and_or_events
      end

      # Creates new future which is resolved after all futures_and_or_events are resolved.
      # Its value is array of zipped future values. Its reason is array of reasons for rejection.
      # If there is an error it rejects.
      # @!macro [new] promises.event-conversion
      #   If event is supplied, which does not have value and can be only resolved, it's
      #   represented as `:fulfilled` with value `nil`.
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Future]
      def zip_futures_on(default_executor, *futures_and_or_events)
        ZipFuturesPromise.new_blocked(futures_and_or_events, default_executor).future
      end

      alias_method :zip, :zip_futures

      # @!macro promises.shortcut.on
      # @return [Event]
      def zip_events(*futures_and_or_events)
        zip_events_on :io, *futures_and_or_events
      end

      # Creates new event which is resolved after all futures_and_or_events are resolved.
      # (Future is resolved when fulfilled or rejected.)
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Event]
      def zip_events_on(default_executor, *futures_and_or_events)
        ZipEventsPromise.new_blocked(futures_and_or_events, default_executor).event
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def any_resolved_future(*futures_and_or_events)
        any_resolved_future_on :io, *futures_and_or_events
      end

      alias_method :any, :any_resolved_future

      # Creates new future which is resolved after first futures_and_or_events is resolved.
      # Its result equals result of the first resolved future.
      # @!macro [new] promises.any-touch
      #   If resolved it does not propagate {AbstractEventFuture#touch}, leaving delayed
      #   futures un-executed if they are not required any more.
      # @!macro promises.event-conversion
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Future]
      def any_resolved_future_on(default_executor, *futures_and_or_events)
        AnyResolvedFuturePromise.new_blocked(futures_and_or_events, default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def any_fulfilled_future(*futures_and_or_events)
        any_fulfilled_future_on :io, *futures_and_or_events
      end

      # Creates new future which is resolved after first of futures_and_or_events is fulfilled.
      # Its result equals result of the first resolved future or if all futures_and_or_events reject,
      # it has reason of the last resolved future.
      # @!macro promises.any-touch
      # @!macro promises.event-conversion
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Future]
      def any_fulfilled_future_on(default_executor, *futures_and_or_events)
        AnyFulfilledFuturePromise.new_blocked(futures_and_or_events, default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def any_event(*futures_and_or_events)
        any_event_on :io, *futures_and_or_events
      end

      # Creates new event which becomes resolved after first of the futures_and_or_events resolves.
      # @!macro promises.any-touch
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Event]
      def any_event_on(default_executor, *futures_and_or_events)
        AnyResolvedEventPromise.new_blocked(futures_and_or_events, default_executor).event
      end

      # TODO consider adding first(count, *futures)
      # TODO consider adding zip_by(slice, *futures) processing futures in slices
    end

    module InternalStates
      # @private
      class State
        def resolved?
          raise NotImplementedError
        end

        def to_sym
          raise NotImplementedError
        end
      end

      private_constant :State

      # @private
      class Pending < State
        def resolved?
          false
        end

        def to_sym
          :pending
        end
      end

      private_constant :Pending

      # @private
      class ResolvedWithResult < State
        def resolved?
          true
        end

        def to_sym
          :resolved
        end

        def result
          [fulfilled?, value, reason]
        end

        def fulfilled?
          raise NotImplementedError
        end

        def value
          raise NotImplementedError
        end

        def reason
          raise NotImplementedError
        end

        def apply
          raise NotImplementedError
        end
      end

      private_constant :ResolvedWithResult

      # @private
      class Fulfilled < ResolvedWithResult

        def initialize(value)
          @Value = value
        end

        def fulfilled?
          true
        end

        def apply(args, block)
          block.call value, *args
        end

        def value
          @Value
        end

        def reason
          nil
        end

        def to_sym
          :fulfilled
        end
      end

      private_constant :Fulfilled

      # @private
      class FulfilledArray < Fulfilled
        def apply(args, block)
          block.call(*value, *args)
        end
      end

      private_constant :FulfilledArray

      # @private
      class Rejected < ResolvedWithResult
        def initialize(reason)
          @Reason = reason
        end

        def fulfilled?
          false
        end

        def value
          nil
        end

        def reason
          @Reason
        end

        def to_sym
          :rejected
        end

        def apply(args, block)
          block.call reason, *args
        end
      end

      private_constant :Rejected

      # @private
      class PartiallyRejected < ResolvedWithResult
        def initialize(value, reason)
          super()
          @Value  = value
          @Reason = reason
        end

        def fulfilled?
          false
        end

        def to_sym
          :rejected
        end

        def value
          @Value
        end

        def reason
          @Reason
        end

        def apply(args, block)
          block.call(*reason, *args)
        end
      end

      private_constant :PartiallyRejected

      PENDING  = Pending.new
      RESOLVED = Fulfilled.new(nil)

      def RESOLVED.to_sym
        :resolved
      end

      private_constant :PENDING, :RESOLVED
    end

    private_constant :InternalStates

    # Common ancestor of {Event} and {Future} classes
    class AbstractEventFuture < Synchronization::Object
      safe_initialization!
      private(*attr_atomic(:internal_state) - [:internal_state])

      include InternalStates

      def initialize(promise, default_executor)
        super()
        @Lock               = Mutex.new
        @Condition          = ConditionVariable.new
        @Promise            = promise
        @DefaultExecutor    = default_executor
        @Callbacks          = LockFreeStack.new
        # noinspection RubyArgCount
        @Waiters            = AtomicFixnum.new 0
        self.internal_state = PENDING
      end

      private :initialize

      # @!macro [new] promises.shortcut.event-future
      #   @see Event#$0
      #   @see Future#$0

      # @!macro [new] promises.param.timeout
      #   @param [Numeric] timeout the maximum time in second to wait.

      # @!macro [new] promises.warn.blocks
      #   @note This function potentially blocks current thread until the Future is resolved.
      #     Be careful it can deadlock. Try to chain instead.

      # Returns its state.
      # @return [Symbol]
      #
      # @overload an_event.state
      #   @return [:pending, :resolved]
      # @overload a_future.state
      #   Both :fulfilled, :rejected implies :resolved.
      #   @return [:pending, :fulfilled, :rejected]
      def state
        internal_state.to_sym
      end

      # Is it in pending state?
      # @return [Boolean]
      def pending?(state = internal_state)
        !state.resolved?
      end

      # Is it in resolved state?
      # @return [Boolean]
      def resolved?(state = internal_state)
        state.resolved?
      end

      # @deprecated
      def unscheduled?
        raise 'unsupported'
      end

      # Propagates touch. Requests all the delayed futures, which it depends on, to be
      # executed. This method is called by any other method requiring resolved state, like {#wait}.
      # @return [self]
      def touch
        @Promise.touch
        self
      end

      # @!macro [new] promises.touches
      #   Calls {AbstractEventFuture#touch}.

      # @!macro [new] promises.method.wait
      #   Wait (block the Thread) until receiver is {#resolved?}.
      #   @!macro promises.touches
      #
      #   @!macro promises.warn.blocks
      #   @!macro promises.param.timeout
      #   @return [Future, true, false] self implies timeout was not used, true implies timeout was used
      #     and it was resolved, false implies it was not resolved within timeout.
      def wait(timeout = nil)
        result = wait_until_resolved(timeout)
        timeout ? result : self
      end

      # Returns default executor.
      # @return [Executor] default executor
      # @see #with_default_executor
      # @see FactoryMethods#future_on
      # @see FactoryMethods#resolvable_future
      # @see FactoryMethods#any_fulfilled_future_on
      # @see similar
      def default_executor
        @DefaultExecutor
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def chain(*args, &task)
        chain_on @DefaultExecutor, *args, &task
      end

      # Chains the task to be executed asynchronously on executor after it is resolved.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @return [Future]
      # @!macro promise.param.task-future
      #
      # @overload an_event.chain_on(executor, *args, &task)
      #   @yield [*args] to the task.
      # @overload a_future.chain_on(executor, *args, &task)
      #   @yield [fulfilled?, value, reason, *args] to the task.
      def chain_on(executor, *args, &task)
        ChainPromise.new_blocked1(self, @DefaultExecutor, executor, args, &task).future
      end

      # @return [String] Short string representation.
      def to_s
        format '<#%s:0x%x %s>', self.class, object_id << 1, state
      end

      alias_method :inspect, :to_s

      # Resolves the resolvable when receiver is resolved.
      #
      # @param [Resolvable] resolvable
      # @return [self]
      def chain_resolvable(resolvable)
        on_resolution! { resolvable.resolve_with internal_state }
      end

      alias_method :tangle, :chain_resolvable

      # @!macro promises.shortcut.using
      # @return [self]
      def on_resolution(*args, &callback)
        on_resolution_using @DefaultExecutor, *args, &callback
      end

      # Stores the callback to be executed synchronously on resolving thread after it is
      # resolved.
      #
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      #
      # @overload an_event.on_resolution!(*args, &callback)
      #   @yield [*args] to the callback.
      # @overload a_future.on_resolution!(*args, &callback)
      #   @yield [fulfilled?, value, reason, *args] to the callback.
      def on_resolution!(*args, &callback)
        add_callback :callback_on_resolution, args, callback
      end

      # Stores the callback to be executed asynchronously on executor after it is resolved.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      #
      # @overload an_event.on_resolution_using(executor, *args, &callback)
      #   @yield [*args] to the callback.
      # @overload a_future.on_resolution_using(executor, *args, &callback)
      #   @yield [fulfilled?, value, reason, *args] to the callback.
      def on_resolution_using(executor, *args, &callback)
        add_callback :async_callback_on_resolution, executor, args, callback
      end

      # @!macro [new] promises.method.with_default_executor
      #   Crates new object with same class with the executor set as its new default executor.
      #   Any futures depending on it will use the new default executor.
      # @!macro promises.shortcut.event-future
      # @abstract
      def with_default_executor(executor)
        raise NotImplementedError
      end

      # @!visibility private
      def resolve_with(state, raise_on_reassign = true)
        if compare_and_set_internal_state(PENDING, state)
          # go to synchronized block only if there were waiting threads
          @Lock.synchronize { @Condition.broadcast } unless @Waiters.value == 0
          call_callbacks state
        else
          return rejected_resolution(raise_on_reassign, state)
        end
        self
      end

      # For inspection.
      # @!visibility private
      # @return [Array<AbstractPromise>]
      def blocks
        @Callbacks.each_with_object([]) do |(method, args), promises|
          promises.push(args[0]) if method == :callback_notify_blocked
        end
      end

      # For inspection.
      # @!visibility private
      def callbacks
        @Callbacks.each.to_a
      end

      # For inspection.
      # @!visibility private
      def promise
        @Promise
      end

      # For inspection.
      # @!visibility private
      def touched?
        promise.touched?
      end

      # For inspection.
      # @!visibility private
      def waiting_threads
        @Waiters.each.to_a
      end

      # @!visibility private
      def add_callback(method, *args)
        state = internal_state
        if resolved?(state)
          call_callback method, state, args
        else
          @Callbacks.push [method, args]
          state = internal_state
          # take back if it was resolved in the meanwhile
          call_callbacks state if resolved?(state)
        end
        self
      end

      private

      # @return [Boolean]
      def wait_until_resolved(timeout)
        return true if resolved?

        touch

        @Lock.synchronize do
          @Waiters.increment
          begin
            unless resolved?
              @Condition.wait @Lock, timeout
            end
          ensure
            # JRuby may raise ConcurrencyError
            @Waiters.decrement
          end
        end
        resolved?
      end

      def call_callback(method, state, args)
        self.send method, state, *args
      end

      def call_callbacks(state)
        method, args = @Callbacks.pop
        while method
          call_callback method, state, args
          method, args = @Callbacks.pop
        end
      end

      def with_async(executor, *args, &block)
        Concurrent.executor(executor).post(*args, &block)
      end

      def async_callback_on_resolution(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_resolution st, ar, cb
        end
      end

      def callback_notify_blocked(state, promise, index)
        promise.on_blocker_resolution self, index
      end
    end

    # Represents an event which will happen in future (will be resolved). The event is either
    # pending or resolved. It should be always resolved. Use {Future} to communicate rejections and
    # cancellation.
    class Event < AbstractEventFuture

      alias_method :then, :chain


      # @!macro [new] promises.method.zip
      #   Creates a new event or a future which will be resolved when receiver and other are.
      #   Returns an event if receiver and other are events, otherwise returns a future.
      #   If just one of the parties is Future then the result
      #   of the returned future is equal to the result of the supplied future. If both are futures
      #   then the result is as described in {FactoryMethods#zip_futures_on}.
      #
      # @return [Future, Event]
      def zip(other)
        if other.is_a?(Future)
          ZipFutureEventPromise.new_blocked2(other, self, @DefaultExecutor).future
        else
          ZipEventEventPromise.new_blocked2(self, other, @DefaultExecutor).event
        end
      end

      alias_method :&, :zip

      # Creates a new event which will be resolved when the first of receiver, `event_or_future`
      # resolves.
      #
      # @return [Event]
      def any(event_or_future)
        AnyResolvedEventPromise.new_blocked2(self, event_or_future, @DefaultExecutor).event
      end

      alias_method :|, :any

      # Creates new event dependent on receiver which will not evaluate until touched, see {#touch}.
      # In other words, it inserts delay into the chain of Futures making rest of it lazy evaluated.
      #
      # @return [Event]
      def delay
        event = DelayPromise.new(@DefaultExecutor).event
        ZipEventEventPromise.new_blocked2(self, event, @DefaultExecutor).event
      end

      # @!macro [new] promise.method.schedule
      #   Creates new event dependent on receiver scheduled to execute on/in intended_time.
      #   In time is interpreted from the moment the receiver is resolved, therefore it inserts
      #   delay into the chain.
      #
      #   @!macro promises.param.intended_time
      # @return [Event]
      def schedule(intended_time)
        chain do
          event = ScheduledPromise.new(@DefaultExecutor, intended_time).event
          ZipEventEventPromise.new_blocked2(self, event, @DefaultExecutor).event
        end.flat_event
      end

      # Converts event to a future. The future is fulfilled when the event is resolved, the future may never fail.
      #
      # @return [Future]
      def to_future
        future = Promises.resolvable_future
      ensure
        chain_resolvable(future)
      end

      # Returns self, since this is event
      # @return [Event]
      def to_event
        self
      end

      # @!macro promises.method.with_default_executor
      # @return [Event]
      def with_default_executor(executor)
        EventWrapperPromise.new_blocked1(self, executor).event
      end

      private

      def rejected_resolution(raise_on_reassign, state)
        Concurrent::MultipleAssignmentError.new('Event can be resolved only once') if raise_on_reassign
        return false
      end

      def callback_on_resolution(state, args, callback)
        callback.call *args
      end
    end

    # Represents a value which will become available in future. May reject with a reason instead,
    # e.g. when the tasks raises an exception.
    class Future < AbstractEventFuture

      # Is it in fulfilled state?
      # @return [Boolean]
      def fulfilled?(state = internal_state)
        state.resolved? && state.fulfilled?
      end

      # Is it in rejected state?
      # @return [Boolean]
      def rejected?(state = internal_state)
        state.resolved? && !state.fulfilled?
      end

      # @!macro [new] promises.warn.nil
      #   @note Make sure returned `nil` is not confused with timeout, no value when rejected,
      #     no reason when fulfilled, etc.
      #     Use more exact methods if needed, like {#wait}, {#value!}, {#result}, etc.

      # @!macro [new] promises.method.value
      #   Return value of the future.
      #   @!macro promises.touches
      #
      #   @!macro promises.warn.blocks
      #   @!macro promises.warn.nil
      #   @!macro promises.param.timeout
      # @return [Object, nil] the value of the Future when fulfilled, nil on timeout or rejection.
      def value(timeout = nil)
        internal_state.value if wait_until_resolved timeout
      end

      # Returns reason of future's rejection.
      # @!macro promises.touches
      #
      # @!macro promises.warn.blocks
      # @!macro promises.warn.nil
      # @!macro promises.param.timeout
      # @return [Exception, nil] nil on timeout or fulfillment.
      def reason(timeout = nil)
        internal_state.reason if wait_until_resolved timeout
      end

      # Returns triplet fulfilled?, value, reason.
      # @!macro promises.touches
      #
      # @!macro promises.warn.blocks
      # @!macro promises.param.timeout
      # @return [Array(Boolean, Object, Exception), nil] triplet of fulfilled?, value, reason, or nil
      #   on timeout.
      def result(timeout = nil)
        internal_state.result if wait_until_resolved timeout
      end

      # @!macro promises.method.wait
      # @raise [Exception] {#reason} on rejection
      def wait!(timeout = nil)
        result = wait_until_resolved!(timeout)
        timeout ? result : self
      end

      # @!macro promises.method.value
      # @return [Object, nil] the value of the Future when fulfilled, nil on timeout.
      # @raise [Exception] {#reason} on rejection
      def value!(timeout = nil)
        internal_state.value if wait_until_resolved! timeout
      end

      # Allows rejected Future to be risen with `raise` method.
      # @example
      #   raise Promises.rejected_future(StandardError.new("boom"))
      # @raise [StandardError] when raising not rejected future
      # @return [Exception]
      def exception(*args)
        raise Concurrent::Error, 'it is not rejected' unless rejected?
        reason = Array(internal_state.reason).compact
        if reason.size > 1
          Concurrent::MultipleErrors.new reason
        else
          reason[0].exception(*args)
        end
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def then(*args, &task)
        then_on @DefaultExecutor, *args, &task
      end

      # Chains the task to be executed asynchronously on executor after it fulfills. Does not run
      # the task if it rejects. It will resolve though, triggering any dependent futures.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.task-future
      # @return [Future]
      # @yield [value, *args] to the task.
      def then_on(executor, *args, &task)
        ThenPromise.new_blocked1(self, @DefaultExecutor, executor, args, &task).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def rescue(*args, &task)
        rescue_on @DefaultExecutor, *args, &task
      end

      # Chains the task to be executed asynchronously on executor after it rejects. Does not run
      # the task if it fulfills. It will resolve though, triggering any dependent futures.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.task-future
      # @return [Future]
      # @yield [reason, *args] to the task.
      def rescue_on(executor, *args, &task)
        RescuePromise.new_blocked1(self, @DefaultExecutor, executor, args, &task).future
      end

      # @!macro promises.method.zip
      # @return [Future]
      def zip(other)
        if other.is_a?(Future)
          ZipFuturesPromise.new_blocked2(self, other, @DefaultExecutor).future
        else
          ZipFutureEventPromise.new_blocked2(self, other, @DefaultExecutor).future
        end
      end

      alias_method :&, :zip

      # Creates a new event which will be resolved when the first of receiver, `event_or_future`
      # resolves. Returning future will have value nil if event_or_future is event and resolves
      # first.
      #
      # @return [Future]
      def any(event_or_future)
        AnyResolvedFuturePromise.new_blocked2(self, event_or_future, @DefaultExecutor).future
      end

      alias_method :|, :any

      # Creates new future dependent on receiver which will not evaluate until touched, see {#touch}.
      # In other words, it inserts delay into the chain of Futures making rest of it lazy evaluated.
      #
      # @return [Future]
      def delay
        event = DelayPromise.new(@DefaultExecutor).event
        ZipFutureEventPromise.new_blocked2(self, event, @DefaultExecutor).future
      end

      # @!macro promise.method.schedule
      # @return [Future]
      def schedule(intended_time)
        chain do
          event = ScheduledPromise.new(@DefaultExecutor, intended_time).event
          ZipFutureEventPromise.new_blocked2(self, event, @DefaultExecutor).future
        end.flat
      end

      # @!macro promises.method.with_default_executor
      # @return [Future]
      def with_default_executor(executor)
        FutureWrapperPromise.new_blocked1(self, executor).future
      end

      # Creates new future which will have result of the future returned by receiver. If receiver
      # rejects it will have its rejection.
      #
      # @param [Integer] level how many levels of futures should flatten
      # @return [Future]
      def flat_future(level = 1)
        FlatFuturePromise.new_blocked1(self, level, @DefaultExecutor).future
      end

      alias_method :flat, :flat_future

      # Creates new event which will be resolved when the returned event by receiver is.
      # Be careful if the receiver rejects it will just resolve since Event does not hold reason.
      #
      # @return [Event]
      def flat_event
        FlatEventPromise.new_blocked1(self, @DefaultExecutor).event
      end

      # @!macro promises.shortcut.using
      # @return [self]
      def on_fulfillment(*args, &callback)
        on_fulfillment_using @DefaultExecutor, *args, &callback
      end

      # Stores the callback to be executed synchronously on resolving thread after it is
      # fulfilled. Does nothing on rejection.
      #
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [value *args] to the callback.
      def on_fulfillment!(*args, &callback)
        add_callback :callback_on_fulfillment, args, callback
      end

      # Stores the callback to be executed asynchronously on executor after it is
      # fulfilled. Does nothing on rejection.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [value *args] to the callback.
      def on_fulfillment_using(executor, *args, &callback)
        add_callback :async_callback_on_fulfillment, executor, args, callback
      end

      # @!macro promises.shortcut.using
      # @return [self]
      def on_rejection(*args, &callback)
        on_rejection_using @DefaultExecutor, *args, &callback
      end

      # Stores the callback to be executed synchronously on resolving thread after it is
      # rejected. Does nothing on fulfillment.
      #
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [reason *args] to the callback.
      def on_rejection!(*args, &callback)
        add_callback :callback_on_rejection, args, callback
      end

      # Stores the callback to be executed asynchronously on executor after it is
      # rejected. Does nothing on fulfillment.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [reason *args] to the callback.
      def on_rejection_using(executor, *args, &callback)
        add_callback :async_callback_on_rejection, executor, args, callback
      end

      # Allows to use futures as green threads. The receiver has to evaluate to a future which
      # represents what should be done next. It basically flattens indefinitely until non Future
      # values is returned which becomes result of the returned future. Any encountered exception
      # will become reason of the returned future.
      #
      # @return [Future]
      # @example
      #   body = lambda do |v|
      #     v += 1
      #     v < 5 ? Promises.future(v, &body) : v
      #   end
      #   Promises.future(0, &body).run.value! # => 5
      def run
        RunFuturePromise.new_blocked1(self, @DefaultExecutor).future
      end

      # @!visibility private
      def apply(args, block)
        internal_state.apply args, block
      end

      # Converts future to event which is resolved when future is resolved by fulfillment or rejection.
      #
      # @return [Event]
      def to_event
        event = Promises.resolvable_event
      ensure
        chain_resolvable(event)
      end

      # Returns self, since this is a future
      # @return [Future]
      def to_future
        self
      end

      private

      def rejected_resolution(raise_on_reassign, state)
        if raise_on_reassign
          raise Concurrent::MultipleAssignmentError.new(
              "Future can be resolved only once. It's #{result}, trying to set #{state.result}.",
              current_result: result, new_result: state.result)
        end
        return false
      end

      def wait_until_resolved!(timeout = nil)
        result = wait_until_resolved(timeout)
        raise self if rejected?
        result
      end

      def async_callback_on_fulfillment(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_fulfillment st, ar, cb
        end
      end

      def async_callback_on_rejection(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_rejection st, ar, cb
        end
      end

      def callback_on_fulfillment(state, args, callback)
        state.apply args, callback if state.fulfilled?
      end

      def callback_on_rejection(state, args, callback)
        state.apply args, callback unless state.fulfilled?
      end

      def callback_on_resolution(state, args, callback)
        callback.call state.result, *args
      end

    end

    # Marker module of Future, Event resolved manually by user.
    module Resolvable
    end

    # A Event which can be resolved by user.
    class ResolvableEvent < Event
      include Resolvable


      # @!macro [new] raise_on_reassign
      # @raise [MultipleAssignmentError] when already resolved and raise_on_reassign is true.

      # @!macro [new] promise.param.raise_on_reassign
      #   @param [Boolean] raise_on_reassign should method raise exception if already resolved
      #   @return [self, false] false is returner when raise_on_reassign is false and the receiver
      #     is already resolved.
      #

      # Makes the event resolved, which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def resolve(raise_on_reassign = true)
        resolve_with RESOLVED, raise_on_reassign
      end

      # Creates new event wrapping receiver, effectively hiding the resolve method.
      #
      # @return [Event]
      def with_hidden_resolvable
        @with_hidden_resolvable ||= EventWrapperPromise.new_blocked1(self, @DefaultExecutor).event
      end
    end

    # A Future which can be resolved by user.
    class ResolvableFuture < Future
      include Resolvable

      # Makes the future resolved with result of triplet `fulfilled?`, `value`, `reason`,
      # which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def resolve(fulfilled = true, value = nil, reason = nil, raise_on_reassign = true)
        resolve_with(fulfilled ? Fulfilled.new(value) : Rejected.new(reason), raise_on_reassign)
      end

      # Makes the future fulfilled with `value`,
      # which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def fulfill(value, raise_on_reassign = true)
        promise.fulfill(value, raise_on_reassign)
      end

      # Makes the future rejected with `reason`,
      # which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def reject(reason, raise_on_reassign = true)
        promise.reject(reason, raise_on_reassign)
      end

      # Evaluates the block and sets its result as future's value fulfilling, if the block raises
      # an exception the future rejects with it.
      # @yield [*args] to the block.
      # @yieldreturn [Object] value
      # @return [self]
      def evaluate_to(*args, &block)
        # FIXME (pitr-ch 13-Jun-2016): add raise_on_reassign
        promise.evaluate_to(*args, block)
      end

      # Evaluates the block and sets its result as future's value fulfilling, if the block raises
      # an exception the future rejects with it.
      # @yield [*args] to the block.
      # @yieldreturn [Object] value
      # @return [self]
      # @raise [Exception] also raise reason on rejection.
      def evaluate_to!(*args, &block)
        promise.evaluate_to!(*args, block)
      end

      # Creates new future wrapping receiver, effectively hiding the resolve method and similar.
      #
      # @return [Future]
      def with_hidden_resolvable
        @with_hidden_resolvable ||= FutureWrapperPromise.new_blocked1(self, @DefaultExecutor).future
      end
    end

    # @abstract
    # @private
    class AbstractPromise < Synchronization::Object
      safe_initialization!
      include InternalStates

      def initialize(future)
        super()
        @Future = future
      end

      def future
        @Future
      end

      alias_method :event, :future

      def default_executor
        future.default_executor
      end

      def state
        future.state
      end

      def touch
      end

      def to_s
        format '<#%s:0x%x>', self.class, object_id << 1
      end

      alias_method :inspect, :to_s

      def delayed
        nil
      end

      private

      def resolve_with(new_state, raise_on_reassign = true)
        @Future.resolve_with(new_state, raise_on_reassign)
      end

      # @return [Future]
      def evaluate_to(*args, block)
        resolve_with Fulfilled.new(block.call(*args))
      rescue Exception => error
        # TODO (pitr-ch 30-Jul-2016): figure out what should be rescued, there is an issue about it
        resolve_with Rejected.new(error)
      end
    end

    class ResolvableEventPromise < AbstractPromise
      def initialize(default_executor)
        super ResolvableEvent.new(self, default_executor)
      end
    end

    class ResolvableFuturePromise < AbstractPromise
      def initialize(default_executor)
        super ResolvableFuture.new(self, default_executor)
      end

      def fulfill(value, raise_on_reassign)
        resolve_with Fulfilled.new(value), raise_on_reassign
      end

      def reject(reason, raise_on_reassign)
        resolve_with Rejected.new(reason), raise_on_reassign
      end

      public :evaluate_to

      def evaluate_to!(*args, block)
        evaluate_to(*args, block).wait!
      end
    end

    # @abstract
    class InnerPromise < AbstractPromise
    end

    # @abstract
    class BlockedPromise < InnerPromise

      private_class_method :new

      def self.new_blocked1(blocker, *args, &block)
        blocker_delayed = blocker.promise.delayed
        delayed         = blocker_delayed ? LockFreeStack.new.push(blocker_delayed) : nil
        promise         = new(delayed, 1, *args, &block)
      ensure
        blocker.add_callback :callback_notify_blocked, promise, 0
      end

      def self.new_blocked2(blocker1, blocker2, *args, &block)
        blocker_delayed1 = blocker1.promise.delayed
        blocker_delayed2 = blocker2.promise.delayed
        # TODO (pitr-ch 23-Dec-2016): use arrays when we know it will not grow (only flat adds delay)
        delayed          = if blocker_delayed1
                             if blocker_delayed2
                               LockFreeStack.of2(blocker_delayed1, blocker_delayed2)
                             else
                               LockFreeStack.of1(blocker_delayed1)
                             end
                           else
                             blocker_delayed2 ? LockFreeStack.of1(blocker_delayed2) : nil
                           end
        promise          = new(delayed, 2, *args, &block)
      ensure
        blocker1.add_callback :callback_notify_blocked, promise, 0
        blocker2.add_callback :callback_notify_blocked, promise, 1
      end

      def self.new_blocked(blockers, *args, &block)
        delayed = blockers.reduce(nil, &method(:add_delayed))
        promise = new(delayed, blockers.size, *args, &block)
      ensure
        blockers.each_with_index { |f, i| f.add_callback :callback_notify_blocked, promise, i }
      end

      def self.add_delayed(delayed, blocker)
        blocker_delayed = blocker.promise.delayed
        if blocker_delayed
          delayed = unless delayed
                      LockFreeStack.of1(blocker_delayed)
                    else
                      delayed.push(blocker_delayed)
                    end
        end
        delayed
      end

      def initialize(delayed, blockers_count, future)
        super(future)
        @Touched   = AtomicBoolean.new false
        @Delayed   = delayed
        @Countdown = AtomicFixnum.new blockers_count
      end

      def on_blocker_resolution(future, index)
        countdown  = process_on_blocker_resolution(future, index)
        resolvable = resolvable?(countdown, future, index)

        on_resolvable(future, index) if resolvable
      end

      def delayed
        @Delayed
      end

      def touch
        clear_propagate_touch if @Touched.make_true
      end

      def touched?
        @Touched.value
      end

      # for inspection only
      def blocked_by
        blocked_by = []
        ObjectSpace.each_object(AbstractEventFuture) { |o| blocked_by.push o if o.blocks.include? self }
        blocked_by
      end

      private

      def clear_propagate_touch
        @Delayed.clear_each { |o| propagate_touch o } if @Delayed
      end

      def propagate_touch(stack_or_element = @Delayed)
        if stack_or_element.is_a? LockFreeStack
          stack_or_element.each { |element| propagate_touch element }
        else
          stack_or_element.touch unless stack_or_element.nil? # if still present
        end
      end

      # @return [true,false] if resolvable
      def resolvable?(countdown, future, index)
        countdown.zero?
      end

      def process_on_blocker_resolution(future, index)
        @Countdown.decrement
      end

      def on_resolvable(resolved_future, index)
        raise NotImplementedError
      end
    end

    # @abstract
    class BlockedTaskPromise < BlockedPromise
      def initialize(delayed, blockers_count, default_executor, executor, args, &task)
        raise ArgumentError, 'no block given' unless block_given?
        super delayed, 1, Future.new(self, default_executor)
        @Executor = executor
        @Task     = task
        @Args     = args
      end

      def executor
        @Executor
      end
    end

    class ThenPromise < BlockedTaskPromise
      private

      def initialize(delayed, blockers_count, default_executor, executor, args, &task)
        super delayed, blockers_count, default_executor, executor, args, &task
      end

      def on_resolvable(resolved_future, index)
        if resolved_future.fulfilled?
          Concurrent.executor(@Executor).post(resolved_future, @Args, @Task) do |future, args, task|
            evaluate_to lambda { future.apply args, task }
          end
        else
          resolve_with resolved_future.internal_state
        end
      end
    end

    class RescuePromise < BlockedTaskPromise
      private

      def initialize(delayed, blockers_count, default_executor, executor, args, &task)
        super delayed, blockers_count, default_executor, executor, args, &task
      end

      def on_resolvable(resolved_future, index)
        if resolved_future.rejected?
          Concurrent.executor(@Executor).post(resolved_future, @Args, @Task) do |future, args, task|
            evaluate_to lambda { future.apply args, task }
          end
        else
          resolve_with resolved_future.internal_state
        end
      end
    end

    class ChainPromise < BlockedTaskPromise
      private

      def on_resolvable(resolved_future, index)
        if Future === resolved_future
          Concurrent.executor(@Executor).post(resolved_future, @Args, @Task) do |future, args, task|
            evaluate_to(*future.result, *args, task)
          end
        else
          Concurrent.executor(@Executor).post(@Args, @Task) do |args, task|
            evaluate_to *args, task
          end
        end
      end
    end

    # will be immediately resolved
    class ImmediateEventPromise < InnerPromise
      def initialize(default_executor)
        super Event.new(self, default_executor).resolve_with(RESOLVED)
      end
    end

    class ImmediateFuturePromise < InnerPromise
      def initialize(default_executor, fulfilled, value, reason)
        super Future.new(self, default_executor).
            resolve_with(fulfilled ? Fulfilled.new(value) : Rejected.new(reason))
      end
    end

    class AbstractFlatPromise < BlockedPromise

      private

      def on_resolvable(resolved_future, index)
        resolve_with resolved_future.internal_state
      end

      def resolvable?(countdown, future, index)
        !@Future.internal_state.resolved? && super(countdown, future, index)
      end

      def add_delayed_of(future)
        if touched?
          propagate_touch future.promise.delayed
        else
          BlockedPromise.add_delayed @Delayed, future
          clear_propagate_touch if touched?
        end
      end

    end

    class FlatEventPromise < AbstractFlatPromise

      private

      def initialize(delayed, blockers_count, default_executor)
        super delayed, 2, Event.new(self, default_executor)
      end

      def process_on_blocker_resolution(future, index)
        countdown = super(future, index)
        if countdown.nonzero?
          internal_state = future.internal_state

          unless internal_state.fulfilled?
            resolve_with RESOLVED
            return countdown
          end

          value = internal_state.value
          case value
          when Future, Event
            add_delayed_of value
            value.add_callback :callback_notify_blocked, self, nil
            countdown
          else
            resolve_with RESOLVED
          end
        end
        countdown
      end

    end

    class FlatFuturePromise < AbstractFlatPromise

      private

      def initialize(delayed, blockers_count, levels, default_executor)
        raise ArgumentError, 'levels has to be higher than 0' if levels < 1
        # flat promise may result to a future having delayed futures, therefore we have to have empty stack
        # to be able to add new delayed futures
        super delayed || LockFreeStack.new, 1 + levels, Future.new(self, default_executor)
      end

      def process_on_blocker_resolution(future, index)
        countdown = super(future, index)
        if countdown.nonzero?
          internal_state = future.internal_state

          unless internal_state.fulfilled?
            resolve_with internal_state
            return countdown
          end

          value = internal_state.value
          case value
          when Future
            add_delayed_of value
            value.add_callback :callback_notify_blocked, self, nil
            countdown
          when Event
            evaluate_to(lambda { raise TypeError, 'cannot flatten to Event' })
          else
            evaluate_to(lambda { raise TypeError, "returned value #{value.inspect} is not a Future" })
          end
        end
        countdown
      end

    end

    class RunFuturePromise < AbstractFlatPromise

      private

      def initialize(delayed, blockers_count, default_executor)
        super delayed, 1, Future.new(self, default_executor)
      end

      def process_on_blocker_resolution(future, index)
        internal_state = future.internal_state

        unless internal_state.fulfilled?
          resolve_with internal_state
          return 0
        end

        value = internal_state.value
        case value
        when Future
          add_delayed_of value
          value.add_callback :callback_notify_blocked, self, nil
        else
          resolve_with internal_state
        end

        1
      end
    end

    class ZipEventEventPromise < BlockedPromise
      def initialize(delayed, blockers_count, default_executor)
        super delayed, 2, Event.new(self, default_executor)
      end

      private

      def on_resolvable(resolved_future, index)
        resolve_with RESOLVED
      end
    end

    class ZipFutureEventPromise < BlockedPromise
      def initialize(delayed, blockers_count, default_executor)
        super delayed, 2, Future.new(self, default_executor)
        @result = nil
      end

      private

      def process_on_blocker_resolution(future, index)
        # first blocking is future, take its result
        @result = future.internal_state if index == 0
        # super has to be called after above to piggyback on volatile @Countdown
        super future, index
      end

      def on_resolvable(resolved_future, index)
        resolve_with @result
      end
    end

    class EventWrapperPromise < BlockedPromise
      def initialize(delayed, blockers_count, default_executor)
        super delayed, 1, Event.new(self, default_executor)
      end

      private

      def on_resolvable(resolved_future, index)
        resolve_with RESOLVED
      end
    end

    class FutureWrapperPromise < BlockedPromise
      def initialize(delayed, blockers_count, default_executor)
        super delayed, 1, Future.new(self, default_executor)
      end

      private

      def on_resolvable(resolved_future, index)
        resolve_with resolved_future.internal_state
      end
    end

    class ZipFuturesPromise < BlockedPromise

      private

      def initialize(delayed, blockers_count, default_executor)
        super(delayed, blockers_count, Future.new(self, default_executor))
        @Resolutions = ::Array.new(blockers_count)

        on_resolvable nil, nil if blockers_count == 0
      end

      def process_on_blocker_resolution(future, index)
        # TODO (pitr-ch 18-Dec-2016): Can we assume that array will never break under parallel access when never re-sized?
        @Resolutions[index] = future.internal_state # has to be set before countdown in super
        super future, index
      end

      def on_resolvable(resolved_future, index)
        all_fulfilled = true
        values        = Array.new(@Resolutions.size)
        reasons       = Array.new(@Resolutions.size)

        @Resolutions.each_with_index do |internal_state, i|
          fulfilled, values[i], reasons[i] = internal_state.result
          all_fulfilled                    &&= fulfilled
        end

        if all_fulfilled
          resolve_with FulfilledArray.new(values)
        else
          resolve_with PartiallyRejected.new(values, reasons)
        end
      end
    end

    class ZipEventsPromise < BlockedPromise

      private

      def initialize(delayed, blockers_count, default_executor)
        super delayed, blockers_count, Event.new(self, default_executor)

        on_resolvable nil, nil if blockers_count == 0
      end

      def on_resolvable(resolved_future, index)
        resolve_with RESOLVED
      end
    end

    # @abstract
    class AbstractAnyPromise < BlockedPromise
    end

    class AnyResolvedFuturePromise < AbstractAnyPromise

      private

      def initialize(delayed, blockers_count, default_executor)
        super delayed, blockers_count, Future.new(self, default_executor)
      end

      def resolvable?(countdown, future, index)
        true
      end

      def on_resolvable(resolved_future, index)
        resolve_with resolved_future.internal_state, false
      end
    end

    class AnyResolvedEventPromise < AbstractAnyPromise

      private

      def initialize(delayed, blockers_count, default_executor)
        super delayed, blockers_count, Event.new(self, default_executor)
      end

      def resolvable?(countdown, future, index)
        true
      end

      def on_resolvable(resolved_future, index)
        resolve_with RESOLVED, false
      end
    end

    class AnyFulfilledFuturePromise < AnyResolvedFuturePromise

      private

      def resolvable?(countdown, future, index)
        future.fulfilled? ||
            # inlined super from BlockedPromise
            countdown.zero?
      end
    end

    class DelayPromise < InnerPromise

      def initialize(default_executor)
        super event = Event.new(self, default_executor)
        @Delayed = LockFreeStack.new.push self
        # TODO (pitr-ch 20-Dec-2016): implement directly without callback?
        event.on_resolution!(@Delayed.peek) { |stack_node| stack_node.value = nil }
      end

      def touch
        @Future.resolve_with RESOLVED
      end

      def delayed
        @Delayed
      end

    end

    class ScheduledPromise < InnerPromise
      def intended_time
        @IntendedTime
      end

      def inspect
        "#{to_s[0..-2]} intended_time: #{@IntendedTime}>"
      end

      private

      def initialize(default_executor, intended_time)
        super Event.new(self, default_executor)

        @IntendedTime = intended_time

        in_seconds = begin
          now           = Time.now
          schedule_time = if @IntendedTime.is_a? Time
                            @IntendedTime
                          else
                            now + @IntendedTime
                          end
          [0, schedule_time.to_f - now.to_f].max
        end

        Concurrent.global_timer_set.post(in_seconds) do
          @Future.resolve_with RESOLVED
        end
      end
    end

    extend FactoryMethods

    private_constant :AbstractPromise,
                     :ResolvableEventPromise,
                     :ResolvableFuturePromise,
                     :InnerPromise,
                     :BlockedPromise,
                     :BlockedTaskPromise,
                     :ThenPromise,
                     :RescuePromise,
                     :ChainPromise,
                     :ImmediateEventPromise,
                     :ImmediateFuturePromise,
                     :AbstractFlatPromise,
                     :FlatFuturePromise,
                     :FlatEventPromise,
                     :RunFuturePromise,
                     :ZipEventEventPromise,
                     :ZipFutureEventPromise,
                     :EventWrapperPromise,
                     :FutureWrapperPromise,
                     :ZipFuturesPromise,
                     :ZipEventsPromise,
                     :AbstractAnyPromise,
                     :AnyResolvedFuturePromise,
                     :AnyFulfilledFuturePromise,
                     :AnyResolvedEventPromise,
                     :DelayPromise,
                     :ScheduledPromise


  end
end

# TODO try stealing pool, each thread has it's own queue
# TODO (pitr-ch 18-Dec-2016): doc macro debug method
# TODO (pitr-ch 18-Dec-2016): add macro noting that debug methods may change api without warning

module Concurrent
  module Promises

    class Future < AbstractEventFuture

      module ActorIntegration
        # Asks the actor with its value.
        # @return [Future] new future with the response form the actor
        def then_ask(actor)
          self.then { |v| actor.ask(v) }.flat
        end
      end

      include ActorIntegration
    end

    # A tool manage concurrency level of future tasks.
    # @example With futures
    #   data     = (1..5).to_a
    #   db       = data.reduce({}) { |h, v| h.update v => v.to_s }
    #   max_two = Promises.throttle 2
    #
    #   futures = data.map do |data|
    #     Promises.future(data) { |data|
    #       # un-throttled, concurrency level equal data.size
    #       data + 1
    #     }.then_throttle(max_two, db) { |v, db|
    #       # throttled, only 2 tasks executed at the same time
    #       # e.g. limiting access to db
    #       db[v]
    #     }
    #   end
    #
    #   futures.map(&:value!) # => [2, 3, 4, 5, nil]
    #
    # @example With Threads
    #   max_two = Concurrent::Throttle.new 2
    #   5.timse
    class Throttle < Synchronization::Object
      # TODO (pitr-ch 23-Dec-2016): move into different file
      # TODO (pitr-ch 23-Dec-2016): move to Concurrent space
      # TODO (pitr-ch 21-Dec-2016): consider using sized channel for implementation instead when available

      safe_initialization!
      private *attr_atomic(:can_run)

      # New throttle.
      # @param [Integer] limit
      def initialize(limit)
        super()
        @Limit       = limit
        self.can_run = limit
        @Queue       = LockFreeQueue.new
      end

      # @return [Integer] The limit.
      def limit
        @Limit
      end

      def trigger
        while true
          current_can_run = can_run
          if compare_and_set_can_run current_can_run, current_can_run - 1
            if current_can_run > 0
              return Promises.resolved_event
            else
              event = Promises.resolvable_event
              @Queue.push event
              return event
            end
          end
        end
      end

      def release
        while true
          current_can_run = can_run
          if compare_and_set_can_run current_can_run, current_can_run + 1
            if current_can_run < 0
              Thread.pass until (trigger = @Queue.pop)
              trigger.resolve
            end
            return self
          end
        end
      end

      # @return [String] Short string representation.
      def to_s
        format '<#%s:0x%x limit:%s can_run:%d>', self.class, object_id << 1, @Limit, can_run
      end

      alias_method :inspect, :to_s

      module PromisesIntegration
        # TODO (pitr-ch 23-Dec-2016): apply similar pattern elsewhere

        def throttled(&throttled_futures)
          throttled_futures.call(trigger).on_resolution! { release }
        end

        def then_throttled(*args, &task)
          trigger.then(*args, &task).on_resolution! { release }
        end
      end

      include PromisesIntegration
    end

    class AbstractEventFuture < Synchronization::Object
      module ThrottleIntegration
        def throttled_by(throttle, &throttled_futures)
          a_trigger = throttle.trigger & self
          throttled_futures.call(a_trigger).on_resolution! { throttle.release }
        end

        def then_throttled_by(throttle, *args, &block)
          throttled_by(throttle) { |trigger| trigger.then(*args, &block) }
        end
      end

      include ThrottleIntegration
    end

    ### Experimental features follow

    module FactoryMethods

      # @!visibility private

      module ChannelIntegration

        # @!visibility private

        # only proof of concept
        # @return [Future]
        def select(*channels)
          # TODO (pitr-ch 26-Mar-2016): re-do, has to be non-blocking
          future do
            # noinspection RubyArgCount
            Channel.select do |s|
              channels.each do |ch|
                s.take(ch) { |value| [value, ch] }
              end
            end
          end
        end
      end

      include ChannelIntegration
    end

    class Future < AbstractEventFuture

      # @!visibility private

      module ChannelIntegration

        # @!visibility private

        # Zips with selected value form the suplied channels
        # @return [Future]
        def then_select(*channels)
          future = Concurrent::Promises.select(*channels)
          ZipFuturesPromise.new_blocked_by2(self, future, @DefaultExecutor).future
        end

        # @note may block
        # @note only proof of concept
        def then_put(channel)
          on_fulfillment_using(:io, channel) { |value, channel| channel.put value }
        end
      end

      include ChannelIntegration
    end

  end
end
