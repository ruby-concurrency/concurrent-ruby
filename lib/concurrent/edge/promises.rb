require 'concurrent/synchronization'
require 'concurrent/atomic/atomic_boolean'
require 'concurrent/atomic/atomic_fixnum'
require 'concurrent/lock_free_stack'
require 'concurrent/concern/logging'
require 'concurrent/errors'

module Concurrent

  # {include:file:doc/promises.out.md}
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
    #     Its returned value becomes {Future#value} succeeding,
    #     raised exception becomes {Future#reason} failing.
    #
    # @!macro [new] promise.param.callback
    #  @yieldreturn is forgotten.

    # Container of all {Future}, {Event} factory methods. They are never constructed directly with
    # new.
    module FactoryMethods


      # @!macro promises.shortcut.on
      # @return [CompletableEvent]
      def completable_event
        completable_event_on :io
      end

      # Created completable event, user is responsible for completing the event once by
      # {Promises::CompletableEvent#complete}.
      #
      # @!macro promises.param.default_executor
      # @return [CompletableEvent]
      def completable_event_on(default_executor = :io)
        CompletableEventPromise.new(default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [CompletableFuture]
      def completable_future
        completable_future_on :io
      end

      # Creates completable future, user is responsible for completing the future once by
      # {Promises::CompletableFuture#complete}, {Promises::CompletableFuture#success},
      # or {Promises::CompletableFuture#fail}
      #
      # @!macro promises.param.default_executor
      # @return [CompletableFuture]
      def completable_future_on(default_executor = :io)
        CompletableFuturePromise.new(default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def future(*args, &task)
        future_on(:io, *args, &task)
      end

      # @!macro [new] promises.future-on1
      #   Constructs new Future which will be completed after block is evaluated on default executor.
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

      # Creates completed future with will be either success with the given value or failed with
      # the given reason.
      #
      # @!macro promises.param.default_executor
      # @return [Future]
      def completed_future(success, value, reason, default_executor = :io)
        ImmediateFuturePromise.new(default_executor, success, value, reason).future
      end

      # Creates completed future with will be success with the given value.
      #
      # @!macro promises.param.default_executor
      # @return [Future]
      def succeeded_future(value, default_executor = :io)
        completed_future true, value, nil, default_executor
      end

      # Creates completed future with will be failed with the given reason.
      #
      # @!macro promises.param.default_executor
      # @return [Future]
      def failed_future(reason, default_executor = :io)
        completed_future false, nil, reason, default_executor
      end

      # Creates completed event.
      #
      # @!macro promises.param.default_executor
      # @return [Event]
      def completed_event(default_executor = :io)
        ImmediateEventPromise.new(default_executor).event
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
        DelayPromise.new(default_executor).future.then(*args, &task)
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

      # Creates new future which is completed after all futures_and_or_events are complete.
      # Its value is array of zipped future values. Its reason is array of reasons for failure.
      # If there is an error it fails.
      # @!macro [new] promises.event-conversion
      #   If event is supplied, which does not have value and can be only completed, it's
      #   represented as `:success` with value `nil`.
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Future]
      def zip_futures_on(default_executor, *futures_and_or_events)
        ZipFuturesPromise.new(futures_and_or_events, default_executor).future
      end

      alias_method :zip, :zip_futures

      # @!macro promises.shortcut.on
      # @return [Event]
      def zip_events(*futures_and_or_events)
        zip_events_on :io, *futures_and_or_events
      end

      # Creates new event which is completed after all futures_and_or_events are complete.
      # (Future is complete when successful or failed.)
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Event]
      def zip_events_on(default_executor, *futures_and_or_events)
        ZipEventsPromise.new(futures_and_or_events, default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def any_complete_future(*futures_and_or_events)
        any_complete_future_on :io, *futures_and_or_events
      end

      alias_method :any, :any_complete_future

      # Creates new future which is completed after first futures_and_or_events is complete.
      # Its result equals result of the first complete future.
      # @!macro [new] promises.any-touch
      #   If complete it does not propagate {AbstractEventFuture#touch}, leaving delayed
      #   futures un-executed if they are not required any more.
      # @!macro promises.event-conversion
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Future]
      def any_complete_future_on(default_executor, *futures_and_or_events)
        AnyCompleteFuturePromise.new(futures_and_or_events, default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def any_successful_future(*futures_and_or_events)
        any_successful_future_on :io, *futures_and_or_events
      end

      # Creates new future which is completed after first of futures_and_or_events is successful.
      # Its result equals result of the first complete future or if all futures_and_or_events fail,
      # it has reason of the last completed future.
      # @!macro promises.any-touch
      # @!macro promises.event-conversion
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Future]
      def any_successful_future_on(default_executor, *futures_and_or_events)
        AnySuccessfulFuturePromise.new(futures_and_or_events, default_executor).future
      end

      # @!macro promises.shortcut.on
      # @return [Future]
      def any_event(*futures_and_or_events)
        any_event_on :io, *futures_and_or_events
      end

      # Creates new event which becomes complete after first of the futures_and_or_events completes.
      # @!macro promises.any-touch
      #
      # @!macro promises.param.default_executor
      # @param [AbstractEventFuture] futures_and_or_events
      # @return [Event]
      def any_event_on(default_executor, *futures_and_or_events)
        AnyCompleteEventPromise.new(futures_and_or_events, default_executor).event
      end

      # TODO consider adding first(count, *futures)
      # TODO consider adding zip_by(slice, *futures) processing futures in slices
    end

    module InternalStates
      class State
        def completed?
          raise NotImplementedError
        end

        def to_sym
          raise NotImplementedError
        end
      end

      private_constant :State

      class Pending < State
        def completed?
          false
        end

        def to_sym
          :pending
        end
      end

      private_constant :Pending

      class CompletedWithResult < State
        def completed?
          true
        end

        def to_sym
          :completed
        end

        def result
          [success?, value, reason]
        end

        def success?
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

      private_constant :CompletedWithResult

      # @!visibility private
      class Success < CompletedWithResult
        def initialize(value)
          @Value = value
        end

        def success?
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
          :success
        end
      end

      private_constant :Success

      # @!visibility private
      class SuccessArray < Success
        def apply(args, block)
          block.call(*value, *args)
        end
      end

      private_constant :SuccessArray

      # @!visibility private
      class Failed < CompletedWithResult
        def initialize(reason)
          @Reason = reason
        end

        def success?
          false
        end

        def value
          nil
        end

        def reason
          @Reason
        end

        def to_sym
          :failed
        end

        def apply(args, block)
          block.call reason, *args
        end
      end

      private_constant :Failed

      # @!visibility private
      class PartiallyFailed < CompletedWithResult
        def initialize(value, reason)
          super()
          @Value  = value
          @Reason = reason
        end

        def success?
          false
        end

        def to_sym
          :failed
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

      private_constant :PartiallyFailed

      PENDING   = Pending.new
      COMPLETED = Success.new(nil)

      private_constant :PENDING, :COMPLETED
    end

    private_constant :InternalStates

    class AbstractEventFuture < Synchronization::Object
      safe_initialization!
      private(*attr_atomic(:internal_state) - [:internal_state])

      include Concern::Logging
      include InternalStates

      def initialize(promise, default_executor)
        super()
        @Lock               = Mutex.new
        @Condition          = ConditionVariable.new
        @Promise            = promise
        @DefaultExecutor    = default_executor
        # noinspection RubyArgCount
        @Touched            = AtomicBoolean.new false
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
      #   @note This function potentially blocks current thread until the Future is complete.
      #     Be careful it can deadlock. Try to chain instead.

      # Returns its state.
      # @return [Symbol]
      #
      # @overload an_event.state
      #   @return [:pending, :completed]
      # @overload a_future.state
      #   Both :success, :failed implies :completed.
      #   @return [:pending, :success, :failed]
      def state
        internal_state.to_sym
      end

      # Is it in pending state?
      # @return [Boolean]
      def pending?(state = internal_state)
        !state.completed?
      end

      # Is it in completed state?
      # @return [Boolean]
      def completed?(state = internal_state)
        state.completed?
      end

      # @deprecated
      def unscheduled?
        raise 'unsupported'
      end

      # Propagates touch. Requests all the delayed futures, which it depends on, to be
      # executed. This method is called by any other method requiring completeness, like {#wait}.
      # @return [self]
      def touch
        # distribute touch to promise only once
        @Promise.touch if @Touched.make_true
        self
      end

      alias_method :needed, :touch

      # @!macro [new] promises.touches
      #   Calls {AbstractEventFuture#touch}.

      # @!macro [new] promises.method.wait
      #   Wait (block the Thread) until receiver is {#completed?}.
      #   @!macro promises.touches
      #
      #   @!macro promises.warn.blocks
      #   @!macro promises.param.timeout
      #   @return [Future, true, false] self implies timeout was not used, true implies timeout was used
      #     and it was completed, false implies it was not completed within timeout.
      def wait(timeout = nil)
        touch
        result = wait_until_complete(timeout)
        timeout ? result : self
      end

      # Returns default executor.
      # @return [Executor] default executor
      # @see #with_default_executor
      # @see FactoryMethods#future_on
      # @see FactoryMethods#completable_future
      # @see FactoryMethods#any_successful_future_on
      # @see similar
      def default_executor
        @DefaultExecutor
      end

      # @!macro promises.shortcut.using
      # @return [Future]
      def chain(*args, &task)
        chain_using @DefaultExecutor, *args, &task
      end

      # Chains the task to be executed asynchronously on executor after it is completed.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @return [Future]
      # @!macro promise.param.task-future
      #
      # @overload an_event.chain_using(executor, *args, &task)
      #   @yield [*args] to the task.
      # @overload a_future.chain_using(executor, *args, &task)
      #   @yield [success, value, reason, *args] to the task.
      def chain_using(executor, *args, &task)
        ChainPromise.new(self, @DefaultExecutor, executor, args, &task).future
      end

      # Short string representation.
      # @return [String]
      def to_s
        "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state.to_sym}>"
      end

      # Longer string representation.
      # @return [String]
      def inspect
        "#{to_s[0..-2]} blocks:[#{blocks.map(&:to_s).join(', ')}]>"
      end

      # @deprecated
      def set(*args, &block)
        raise 'Use CompletableEvent#complete or CompletableFuture#complete instead, ' +
                  'constructed by Promises.completable_event or Promises.completable_future respectively.'
      end

      # Completes the completable when receiver is completed.
      #
      # @param [Completable] completable
      # @return [self]
      def chain_completable(completable)
        on_completion! { completable.complete_with internal_state }
      end

      alias_method :tangle, :chain_completable

      # @!macro promises.shortcut.using
      # @return [self]
      def on_completion(*args, &callback)
        on_completion_using @DefaultExecutor, *args, &callback
      end

      # Stores the callback to be executed synchronously on completing thread after it is
      # completed.
      #
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      #
      # @overload an_event.on_completion!(*args, &callback)
      #   @yield [*args] to the callback.
      # @overload a_future.on_completion!(*args, &callback)
      #   @yield [success, value, reason, *args] to the callback.
      def on_completion!(*args, &callback)
        add_callback :callback_on_completion, args, callback
      end

      # Stores the callback to be executed asynchronously on executor after it is completed.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      #
      # @overload an_event.on_completion_using(executor, *args, &callback)
      #   @yield [*args] to the callback.
      # @overload a_future.on_completion_using(executor, *args, &callback)
      #   @yield [success, value, reason, *args] to the callback.
      def on_completion_using(executor, *args, &callback)
        add_callback :async_callback_on_completion, executor, args, callback
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
      def complete_with(state, raise_on_reassign = true)
        if compare_and_set_internal_state(PENDING, state)
          # go to synchronized block only if there were waiting threads
          @Lock.synchronize { @Condition.broadcast } unless @Waiters.value == 0
          call_callbacks state
        else
          return failed_complete(raise_on_reassign, state)
        end
        self
      end

      # For inspection.
      # @!visibility private
      # @return [Array<AbstractPromise>]
      def blocks
        @Callbacks.each_with_object([]) do |callback, promises|
          promises.push(*(callback.select { |v| v.is_a? AbstractPromise }))
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
      def touched
        @Touched.value
      end

      # For inspection.
      # @!visibility private
      def waiting_threads
        @Waiters.each.to_a
      end

      # @!visibility private
      def add_callback(method, *args)
        state = internal_state
        if completed?(state)
          call_callback method, state, *args
        else
          @Callbacks.push [method, *args]
          state = internal_state
          # take back if it was completed in the meanwhile
          call_callbacks state if completed?(state)
        end
        self
      end

      private

      # @return [Boolean]
      def wait_until_complete(timeout)
        return true if completed?

        @Lock.synchronize do
          begin
            unless completed?
              @Condition.wait @Lock, timeout
            end
          ensure
            # JRuby may raise ConcurrencyError
            @Waiters.decrement
          end
        end
        completed?
      end

      def call_callback(method, state, *args)
        self.send method, state, *args
      end

      def call_callbacks(state)
        method, *args = @Callbacks.pop
        while method
          call_callback method, state, *args
          method, *args = @Callbacks.pop
        end
      end

      def with_async(executor, *args, &block)
        Concurrent.executor(executor).post(*args, &block)
      end

      def async_callback_on_completion(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_completion st, ar, cb
        end
      end

      def callback_notify_blocked(state, promise)
        promise.on_done self
      end
    end

    # Represents an event which will happen in future (will be completed). The event is either
    # pending or completed. It should be always completed. Use {Future} to communicate failures and
    # cancellation.
    class Event < AbstractEventFuture

      alias_method :then, :chain


      # @!macro [new] promises.method.zip
      #   Creates a new event or a future which will be completed when receiver and other are.
      #   Returns an event if receiver and other are events, otherwise returns a future.
      #   If just one of the parties is Future then the result
      #   of the returned future is equal to the result of the supplied future. If both are futures
      #   then the result is as described in {FactoryMethods#zip_futures_on}.
      #
      # @return [Future, Event]
      def zip(other)
        if other.is?(Future)
          ZipFutureEventPromise.new(other, self, @DefaultExecutor).future
        else
          ZipEventEventPromise.new(self, other, @DefaultExecutor).event
        end
      end

      alias_method :&, :zip

      # Creates a new event which will be completed when the first of receiver, `event_or_future`
      # completes.
      #
      # @return [Event]
      def any(event_or_future)
        AnyCompleteEventPromise.new([self, event_or_future], @DefaultExecutor).event
      end

      alias_method :|, :any

      # Creates new event dependent on receiver which will not evaluate until touched, see {#touch}.
      # In other words, it inserts delay into the chain of Futures making rest of it lazy evaluated.
      #
      # @return [Event]
      def delay
        ZipEventEventPromise.new(self,
                                 DelayPromise.new(@DefaultExecutor).event,
                                 @DefaultExecutor).event
      end

      # @!macro [new] promise.method.schedule
      #   Creates new event dependent on receiver scheduled to execute on/in intended_time.
      #   In time is interpreted from the moment the receiver is completed, therefore it inserts
      #   delay into the chain.
      #
      #   @!macro promises.param.intended_time
      # @return [Event]
      def schedule(intended_time)
        chain do
          ZipEventEventPromise.new(self,
                                   ScheduledPromise.new(@DefaultExecutor, intended_time).event,
                                   @DefaultExecutor).event
        end.flat_event
      end

      # TODO (pitr-ch 12-Jun-2016): add to_event, to_future

      # @!macro promises.method.with_default_executor
      # @return [Event]
      def with_default_executor(executor)
        EventWrapperPromise.new(self, executor).future
      end

      private

      def failed_complete(raise_on_reassign, state)
        Concurrent::MultipleAssignmentError.new('Event can be completed only once') if raise_on_reassign
        return false
      end

      def callback_on_completion(state, args, callback)
        callback.call *args
      end
    end

    # Represents a value which will become available in future. May fail with a reason instead,
    # e.g. when the tasks raises an exception.
    class Future < AbstractEventFuture

      # Is it in success state?
      # @return [Boolean]
      def success?(state = internal_state)
        state.completed? && state.success?
      end

      # Is it in failed state?
      # @return [Boolean]
      def failed?(state = internal_state)
        state.completed? && !state.success?
      end

      # @!macro [new] promises.warn.nil
      #   @note Make sure returned `nil` is not confused with timeout, no value when failed,
      #     no reason when success, etc.
      #     Use more exact methods if needed, like {#wait}, {#value!}, {#result}, etc.

      # @!macro [new] promises.method.value
      #   Return value of the future.
      #   @!macro promises.touches
      #
      #   @!macro promises.warn.blocks
      #   @!macro promises.warn.nil
      #   @!macro promises.param.timeout
      # @return [Object, nil] the value of the Future when success, nil on timeout or failure.
      def value(timeout = nil)
        touch
        internal_state.value if wait_until_complete timeout
      end

      # Returns reason of future's failure.
      # @!macro promises.touches
      #
      # @!macro promises.warn.blocks
      # @!macro promises.warn.nil
      # @!macro promises.param.timeout
      # @return [Exception, nil] nil on timeout or success.
      def reason(timeout = nil)
        touch
        internal_state.reason if wait_until_complete timeout
      end

      # Returns triplet success?, value, reason.
      # @!macro promises.touches
      #
      # @!macro promises.warn.blocks
      # @!macro promises.param.timeout
      # @return [Array(Boolean, Object, Exception), nil] triplet of success, value, reason, or nil
      #   on timeout.
      def result(timeout = nil)
        touch
        internal_state.result if wait_until_complete timeout
      end

      # @!macro promises.method.wait
      # @raise [Exception] {#reason} on failure
      def wait!(timeout = nil)
        touch
        result = wait_until_complete!(timeout)
        timeout ? result : self
      end

      # @!macro promises.method.value
      # @return [Object, nil] the value of the Future when success, nil on timeout.
      # @raise [Exception] {#reason} on failure
      def value!(timeout = nil)
        touch
        internal_state.value if wait_until_complete! timeout
      end

      # Allows failed Future to be risen with `raise` method.
      # @example
      #   raise Promises.failed_future(StandardError.new("boom"))
      # @raise [StandardError] when raising not failed future
      def exception(*args)
        raise Concurrent::Error, 'it is not failed' unless failed?
        reason = internal_state.reason
        if reason.is_a?(::Array)
          # TODO (pitr-ch 12-Jun-2016): remove logging!, how?
          reason.each { |e| log ERROR, 'Promises::Future', e }
          Concurrent::Error.new 'multiple exceptions, inspect log'
        else
          reason.exception(*args)
        end
      end

      # @!macro promises.shortcut.using
      # @return [Future]
      def then(*args, &task)
        then_using @DefaultExecutor, *args, &task
      end

      # Chains the task to be executed asynchronously on executor after it succeeds. Does not run
      # the task if it fails. It will complete though, triggering any dependent futures.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.task-future
      # @return [Future]
      # @yield [value, *args] to the task.
      def then_using(executor, *args, &task)
        ThenPromise.new(self, @DefaultExecutor, executor, args, &task).future
      end

      # @!macro promises.shortcut.using
      # @return [Future]
      def rescue(*args, &task)
        rescue_using @DefaultExecutor, *args, &task
      end

      # Chains the task to be executed asynchronously on executor after it fails. Does not run
      # the task if it succeeds. It will complete though, triggering any dependent futures.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.task-future
      # @return [Future]
      # @yield [reason, *args] to the task.
      def rescue_using(executor, *args, &task)
        RescuePromise.new(self, @DefaultExecutor, executor, args, &task).future
      end

      # @!macro promises.method.zip
      # @return [Future]
      def zip(other)
        if other.is_a?(Future)
          ZipFutureFuturePromise.new(self, other, @DefaultExecutor).future
        else
          ZipFutureEventPromise.new(self, other, @DefaultExecutor).future
        end
      end

      alias_method :&, :zip

      # Creates a new event which will be completed when the first of receiver, `event_or_future`
      # completes. Returning future will have value nil if event_or_future is event and completes
      # first.
      #
      # @return [Future]
      def any(event_or_future)
        AnyCompleteFuturePromise.new([self, event_or_future], @DefaultExecutor).future
      end

      alias_method :|, :any

      # Creates new future dependent on receiver which will not evaluate until touched, see {#touch}.
      # In other words, it inserts delay into the chain of Futures making rest of it lazy evaluated.
      #
      # @return [Future]
      def delay
        ZipFutureEventPromise.new(self,
                                  DelayPromise.new(@DefaultExecutor).future,
                                  @DefaultExecutor).future
      end

      # @!macro promise.method.schedule
      # @return [Future]
      def schedule(intended_time)
        chain do
          ZipFutureEventPromise.new(self,
                                    ScheduledPromise.new(@DefaultExecutor, intended_time).event,
                                    @DefaultExecutor).future
        end.flat
      end

      # @!macro promises.method.with_default_executor
      # @return [Future]
      def with_default_executor(executor)
        FutureWrapperPromise.new(self, executor).future
      end

      # Creates new future which will have result of the future returned by receiver. If receiver
      # fails it will have its failure.
      #
      # @param [Integer] level how many levels of futures should flatten
      # @return [Future]
      def flat_future(level = 1)
        FlatFuturePromise.new(self, level, @DefaultExecutor).future
      end

      alias_method :flat, :flat_future

      # Creates new event which will be completed when the returned event by receiver is.
      # Be careful if the receiver fails it will just complete since Event does not hold reason.
      #
      # @return [Event]
      def flat_event
        FlatEventPromise.new(self, @DefaultExecutor).event
      end

      # @!macro promises.shortcut.using
      # @return [self]
      def on_success(*args, &callback)
        on_success_using @DefaultExecutor, *args, &callback
      end

      # Stores the callback to be executed synchronously on completing thread after it is
      # successful. Does nothing on failure.
      #
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [value *args] to the callback.
      def on_success!(*args, &callback)
        add_callback :callback_on_success, args, callback
      end

      # Stores the callback to be executed asynchronously on executor after it is
      # successful. Does nothing on failure.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [value *args] to the callback.
      def on_success_using(executor, *args, &callback)
        add_callback :async_callback_on_success, executor, args, callback
      end

      # @!macro promises.shortcut.using
      # @return [self]
      def on_failure(*args, &callback)
        on_failure_using @DefaultExecutor, *args, &callback
      end

      # Stores the callback to be executed synchronously on completing thread after it is
      # failed. Does nothing on success.
      #
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [reason *args] to the callback.
      def on_failure!(*args, &callback)
        add_callback :callback_on_failure, args, callback
      end

      # Stores the callback to be executed asynchronously on executor after it is
      # failed. Does nothing on success.
      #
      # @!macro promises.param.executor
      # @!macro promises.param.args
      # @!macro promise.param.callback
      # @return [self]
      # @yield [reason *args] to the callback.
      def on_failure_using(executor, *args, &callback)
        add_callback :async_callback_on_failure, executor, args, callback
      end

      # Allows to use futures as green threads. The receiver has to evaluate to a future which
      # represents what should be done next. It basically flattens indefinitely until non Future
      # values is returned which becomes result of the returned future. Any ancountered exception
      # will become reason of the returned future.
      #
      # @return [Future]
      # @example
      #   body = lambda do |v|
      #    v += 1
      #    v < 5 ? future(v, &body) : v
      #   end
      #   future(0, &body).run.value! # => 5
      def run
        RunFuturePromise.new(self, @DefaultExecutor).future
      end

      # @!visibility private
      def apply(args, block)
        internal_state.apply args, block
      end

      private

      def failed_complete(raise_on_reassign, state)
        if raise_on_reassign
          # TODO (pitr-ch 12-Jun-2016): remove logging?!
          # print otherwise hidden error
          log ERROR, 'Promises::Future', reason if reason
          log ERROR, 'Promises::Future', state.reason if state.reason

          raise(Concurrent::MultipleAssignmentError.new(
              "Future can be completed only once. Current result is #{result}, " +
                  "trying to set #{state.result}"))
        end
        return false
      end

      def wait_until_complete!(timeout = nil)
        result = wait_until_complete(timeout)
        raise self if failed?
        result
      end

      def async_callback_on_success(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_success st, ar, cb
        end
      end

      def async_callback_on_failure(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_failure st, ar, cb
        end
      end

      def callback_on_success(state, args, callback)
        state.apply args, callback if state.success?
      end

      def callback_on_failure(state, args, callback)
        state.apply args, callback unless state.success?
      end

      def callback_on_completion(state, args, callback)
        callback.call state.result, *args
      end

    end

    # Marker module of Future, Event completed manually by user.
    module Completable
    end

    # A Event which can be completed by user.
    class CompletableEvent < Event
      include Completable


      # @!macro [new] raise_on_reassign
      # @raise [MultipleAssignmentError] when already completed and raise_on_reassign is true.

      # @!macro [new] promise.param.raise_on_reassign
      #   @param [Boolean] raise_on_reassign should method raise exception if already completed
      #   @return [self, false] false is returner when raise_on_reassign is false and the receiver
      #     is already completed.
      #

      # Makes the event complete, which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def complete(raise_on_reassign = true)
        complete_with COMPLETED, raise_on_reassign
      end

      # Creates new event wrapping receiver, effectively hiding the complete method.
      #
      # @return [Event]
      def with_hidden_completable
        @with_hidden_completable ||= EventWrapperPromise.new(self, @DefaultExecutor).event
      end
    end

    # A Future which can be completed by user.
    class CompletableFuture < Future
      include Completable

      # Makes the future complete with result of triplet `success`, `value`, `reason`,
      # which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def complete(success, value, reason, raise_on_reassign = true)
        complete_with(success ? Success.new(value) : Failed.new(reason), raise_on_reassign)
      end

      # Makes the future successful with `value`,
      # which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def success(value, raise_on_reassign = true)
        promise.success(value, raise_on_reassign)
      end

      # Makes the future failed with `reason`,
      # which triggers all dependent futures.
      #
      # @!macro promise.param.raise_on_reassign
      def fail(reason, raise_on_reassign = true)
        promise.fail(reason, raise_on_reassign)
      end

      # Evaluates the block and sets its result as future's value succeeding, if the block raises
      # an exception the future fails with it.
      # @yield [*args] to the block.
      # @yieldreturn [Object] value
      # @return [self]
      def evaluate_to(*args, &block)
        # TODO (pitr-ch 13-Jun-2016): add raise_on_reassign
        promise.evaluate_to(*args, block)
      end

      # Evaluates the block and sets its result as future's value succeeding, if the block raises
      # an exception the future fails with it.
      # @yield [*args] to the block.
      # @yieldreturn [Object] value
      # @return [self]
      # @raise [Exception] also raise reason on failure.
      def evaluate_to!(*args, &block)
        promise.evaluate_to!(*args, block)
      end

      # Creates new future wrapping receiver, effectively hiding the complete method and similar.
      #
      # @return [Future]
      def with_hidden_completable
        @with_hidden_completable ||= FutureWrapperPromise.new(self, @DefaultExecutor).future
      end
    end

    # @abstract
    class AbstractPromise < Synchronization::Object
      safe_initialization!
      include InternalStates
      include Concern::Logging

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
        "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state}>"
      end

      def inspect
        to_s
      end

      private

      def complete_with(new_state, raise_on_reassign = true)
        @Future.complete_with(new_state, raise_on_reassign)
      end

      # @return [Future]
      def evaluate_to(*args, block)
        complete_with Success.new(block.call(*args))
      rescue StandardError => error
        complete_with Failed.new(error)
      rescue Exception => error
        # TODO (pitr-ch 12-Jun-2016): remove logging?
        log(ERROR, 'Promises::Future', error)
        complete_with Failed.new(error)
      end
    end

    class CompletableEventPromise < AbstractPromise
      def initialize(default_executor)
        super CompletableEvent.new(self, default_executor)
      end
    end

    class CompletableFuturePromise < AbstractPromise
      def initialize(default_executor)
        super CompletableFuture.new(self, default_executor)
      end

      def success(value, raise_on_reassign)
        complete_with Success.new(value), raise_on_reassign
      end

      def fail(reason, raise_on_reassign)
        complete_with Failed.new(reason), raise_on_reassign
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
      def self.new(*args, &block)
        promise = super(*args, &block)
        promise.blocked_by.each { |f| f.add_callback :callback_notify_blocked, promise }
        promise
      end

      def initialize(future, blocked_by_futures, countdown)
        super(future)
        initialize_blocked_by(blocked_by_futures)
        @Countdown = AtomicFixnum.new countdown
      end

      # @api private
      def on_done(future)
        countdown   = process_on_done(future)
        completable = completable?(countdown, future)

        if completable
          on_completable(future)
          # futures could be deleted from blocked_by one by one here, but that would be too expensive,
          # it's done once when all are done to free the reference
          clear_blocked_by!
        end
      end

      def touch
        # TODO (pitr-ch 13-Jun-2016): track if it has lazy parent if it's needed avoids CASes!
        blocked_by.each(&:touch)
      end

      # !visibility private
      # for inspection only
      def blocked_by
        @BlockedBy
      end

      def inspect
        "#{to_s[0..-2]} blocked_by:[#{ blocked_by.map(&:to_s).join(', ')}]>"
      end

      private

      def initialize_blocked_by(blocked_by_futures)
        unless blocked_by_futures.is_a?(::Array)
          raise ArgumentError, "has to be array of events/futures: #{blocked_by_futures.inspect}"
        end
        @BlockedBy = blocked_by_futures
      end

      def clear_blocked_by!
        # not synchronized because we do not care when this change propagates
        @BlockedBy = []
        nil
      end

      # @return [true,false] if completable
      def completable?(countdown, future)
        countdown.zero?
      end

      def process_on_done(future)
        @Countdown.decrement
      end

      def on_completable(done_future)
        raise NotImplementedError
      end
    end

    # @abstract
    class BlockedTaskPromise < BlockedPromise
      def initialize(blocked_by_future, default_executor, executor, args, &task)
        raise ArgumentError, 'no block given' unless block_given?
        super Future.new(self, default_executor), [blocked_by_future], 1
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

      def initialize(blocked_by_future, default_executor, executor, args, &task)
        raise ArgumentError, 'only Future can be appended with then' unless blocked_by_future.is_a? Future
        super blocked_by_future, default_executor, executor, args, &task
      end

      def on_completable(done_future)
        if done_future.success?
          Concurrent.executor(@Executor).post(done_future, @Args, @Task) do |future, args, task|
            evaluate_to lambda { future.apply args, task }
          end
        else
          complete_with done_future.internal_state
        end
      end
    end

    class RescuePromise < BlockedTaskPromise
      private

      def initialize(blocked_by_future, default_executor, executor, args, &task)
        super blocked_by_future, default_executor, executor, args, &task
      end

      def on_completable(done_future)
        if done_future.failed?
          Concurrent.executor(@Executor).post(done_future, @Args, @Task) do |future, args, task|
            evaluate_to lambda { future.apply args, task }
          end
        else
          complete_with done_future.internal_state
        end
      end
    end

    class ChainPromise < BlockedTaskPromise
      private

      def on_completable(done_future)
        if Future === done_future
          Concurrent.executor(@Executor).post(done_future, @Args, @Task) do |future, args, task|
            evaluate_to(*future.result, *args, task)
          end
        else
          Concurrent.executor(@Executor).post(@Args, @Task) do |args, task|
            evaluate_to *args, task
          end
        end
      end
    end

    # will be immediately completed
    class ImmediateEventPromise < InnerPromise
      def initialize(default_executor)
        super Event.new(self, default_executor).complete_with(COMPLETED)
      end
    end

    class ImmediateFuturePromise < InnerPromise
      def initialize(default_executor, success, value, reason)
        super Future.new(self, default_executor).
            complete_with(success ? Success.new(value) : Failed.new(reason))
      end
    end

    class AbstractFlatPromise < BlockedPromise
      # !visibility private
      def blocked_by
        @BlockedBy.each.to_a
      end

      private

      def initialize_blocked_by(blocked_by_future)
        @BlockedBy = LockFreeStack.new.push(blocked_by_future)
      end

      def on_completable(done_future)
        complete_with done_future.internal_state
      end

      def clear_blocked_by!
        @BlockedBy.clear
        nil
      end

      def completable?(countdown, future)
        !@Future.internal_state.completed? && super(countdown, future)
      end
    end

    class FlatEventPromise < AbstractFlatPromise

      private

      def initialize(blocked_by_future, default_executor)
        super Event.new(self, default_executor), blocked_by_future, 2
      end

      def process_on_done(future)
        countdown = super(future)
        if countdown.nonzero?
          internal_state = future.internal_state

          unless internal_state.success?
            complete_with COMPLETED
            return countdown
          end

          value = internal_state.value
          case value
          when Future, Event
            @BlockedBy.push value
            value.add_callback :callback_notify_blocked, self
            @Countdown.value
          else
            complete_with COMPLETED
          end
        end
        countdown
      end

    end

    class FlatFuturePromise < AbstractFlatPromise

      private

      def initialize(blocked_by_future, levels, default_executor)
        raise ArgumentError, 'levels has to be higher than 0' if levels < 1
        super Future.new(self, default_executor), blocked_by_future, 1 + levels
      end

      def process_on_done(future)
        countdown = super(future)
        if countdown.nonzero?
          internal_state = future.internal_state

          unless internal_state.success?
            complete_with internal_state
            return countdown
          end

          value = internal_state.value
          case value
          when Future
            @BlockedBy.push value
            value.add_callback :callback_notify_blocked, self
            @Countdown.value
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

      def initialize(blocked_by_future, default_executor)
        super Future.new(self, default_executor), blocked_by_future, 1
      end

      def process_on_done(future)
        internal_state = future.internal_state

        unless internal_state.success?
          complete_with internal_state
          return 0
        end

        value = internal_state.value
        case value
        when Future
          # @BlockedBy.push value
          value.add_callback :callback_notify_blocked, self
        else
          complete_with internal_state
        end

        1
      end
    end

    class ZipEventEventPromise < BlockedPromise
      def initialize(event1, event2, default_executor)
        super Event.new(self, default_executor), [event1, event2], 2
      end

      def on_completable(done_future)
        complete_with COMPLETED
      end
    end

    class ZipFutureEventPromise < BlockedPromise
      def initialize(future, event, default_executor)
        super Future.new(self, default_executor), [future, event], 2
        @FutureResult = future
      end

      def on_completable(done_future)
        complete_with @FutureResult.internal_state
      end
    end

    class ZipFutureFuturePromise < BlockedPromise
      def initialize(future1, future2, default_executor)
        super Future.new(self, default_executor), [future1, future2], 2
        @Future1Result = future1
        @Future2Result = future2
      end

      def on_completable(done_future)
        success1, value1, reason1 = @Future1Result.result
        success2, value2, reason2 = @Future2Result.result
        success                   = success1 && success2
        new_state                 = if success
                                      SuccessArray.new([value1, value2])
                                    else
                                      PartiallyFailed.new([value1, value2], [reason1, reason2])
                                    end
        complete_with new_state
      end
    end

    class EventWrapperPromise < BlockedPromise
      def initialize(event, default_executor)
        super Event.new(self, default_executor), [event], 1
      end

      def on_completable(done_future)
        complete_with COMPLETED
      end
    end

    class FutureWrapperPromise < BlockedPromise
      def initialize(future, default_executor)
        super Future.new(self, default_executor), [future], 1
      end

      def on_completable(done_future)
        complete_with done_future.internal_state
      end
    end

    class ZipFuturesPromise < BlockedPromise

      private

      def initialize(blocked_by_futures, default_executor)
        super(Future.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)

        on_completable nil if blocked_by_futures.empty?
      end

      def on_completable(done_future)
        all_success = true
        values      = Array.new(blocked_by.size)
        reasons     = Array.new(blocked_by.size)

        blocked_by.each_with_index do |future, i|
          if future.is_a?(Future)
            success, values[i], reasons[i] = future.result
            all_success                    &&= success
          else
            values[i] = reasons[i] = nil
          end
        end

        if all_success
          complete_with SuccessArray.new(values)
        else
          complete_with PartiallyFailed.new(values, reasons)
        end
      end
    end

    class ZipEventsPromise < BlockedPromise

      private

      def initialize(blocked_by_futures, default_executor)
        super(Event.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)

        on_completable nil if blocked_by_futures.empty?
      end

      def on_completable(done_future)
        complete_with COMPLETED
      end
    end

    # @abstract
    class AbstractAnyPromise < BlockedPromise
      def touch
        blocked_by.each(&:touch) unless @Future.completed?
      end
    end

    class AnyCompleteFuturePromise < AbstractAnyPromise

      private

      def initialize(blocked_by_futures, default_executor)
        super(Future.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)
      end

      def completable?(countdown, future)
        true
      end

      def on_completable(done_future)
        complete_with done_future.internal_state, false
      end
    end

    class AnyCompleteEventPromise < AbstractAnyPromise

      private

      def initialize(blocked_by_futures, default_executor)
        super(Event.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)
      end

      def completable?(countdown, future)
        true
      end

      def on_completable(done_future)
        complete_with COMPLETED, false
      end
    end

    class AnySuccessfulFuturePromise < AnyCompleteFuturePromise

      private

      def completable?(countdown, future)
        future.success? ||
            # inlined super from BlockedPromise
            countdown.zero?
      end
    end

    class DelayPromise < InnerPromise
      def touch
        @Future.complete_with COMPLETED
      end

      private

      def initialize(default_executor)
        super Event.new(self, default_executor)
      end
    end

    class ScheduledPromise < InnerPromise
      def intended_time
        @IntendedTime
      end

      def inspect
        "#{to_s[0..-2]} intended_time:[#{@IntendedTime}}>"
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
          @Future.complete_with COMPLETED
        end
      end
    end

    extend FactoryMethods

    private_constant :AbstractPromise,
                     :CompletableEventPromise,
                     :CompletableFuturePromise,
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
                     :ZipFutureFuturePromise,
                     :EventWrapperPromise,
                     :FutureWrapperPromise,
                     :ZipFuturesPromise,
                     :ZipEventsPromise,
                     :AbstractAnyPromise,
                     :AnyCompleteFuturePromise,
                     :AnySuccessfulFuturePromise,
                     :AnyCompleteEventPromise,
                     :DelayPromise,
                     :ScheduledPromise


  end
end

# TODO try stealing pool, each thread has it's own queue

### Experimental features follow
module Concurrent
  module Promises
    module FactoryMethods

      # @!visibility private

      # only proof of concept
      # @return [Future]
      def select(*channels)
        # TODO (pitr-ch 26-Mar-2016): redo, has to be non-blocking
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

    class Future < AbstractEventFuture

      # @!visibility private

      # Zips with selected value form the suplied channels
      # @return [Future]
      def then_select(*channels)
        ZipFuturesPromise.new([self, Concurrent::Promises.select(*channels)], @DefaultExecutor).future
      end

      # @note may block
      # @note only proof of concept
      def then_put(channel)
        on_success(:io) { |value| channel.put value }
      end

      # Asks the actor with its value.
      # @return [Future] new future with the response form the actor
      def then_ask(actor)
        self.then { |v| actor.ask(v) }.flat
      end

      include Enumerable

      def each(&block)
        each_body self.value, &block
      end

      def each!(&block)
        each_body self.value!, &block
      end

      private

      def each_body(value, &block)
        (value.nil? ? [nil] : Array(value)).each(&block)
      end

    end
  end

  # inspired by https://msdn.microsoft.com/en-us/library/dd537607(v=vs.110).aspx
  class Cancellation < Synchronization::Object
    safe_initialization!

    def self.create(future_or_event = Promises.completable_event, *complete_args)
      [(i = new(future_or_event, *complete_args)), i.token]
    end

    private_class_method :new

    def initialize(future, *complete_args)
      raise ArgumentError, 'future is not Completable' unless future.is_a?(Promises::Completable)
      @Cancel       = future
      @Token        = Token.new @Cancel.with_hidden_completable
      @CompleteArgs = complete_args
    end

    def token
      @Token
    end

    def cancel(raise_on_repeated_call = true)
      !!@Cancel.complete(*@CompleteArgs, raise_on_repeated_call)
    end

    def canceled?
      @Cancel.completed?
    end

    class Token < Synchronization::Object
      safe_initialization!

      def initialize(cancel)
        @Cancel = cancel
      end

      def event
        @Cancel
      end

      alias_method :future, :event

      def on_cancellation(*args, &block)
        @Cancel.on_completion *args, &block
      end

      def then(*args, &block)
        @Cancel.chain *args, &block
      end

      def canceled?
        @Cancel.completed?
      end

      def loop_until_canceled(&block)
        until canceled?
          result = block.call
        end
        result
      end

      def raise_if_canceled
        raise CancelledOperationError if canceled?
        self
      end

      def join(*tokens)
        Token.new Promises.any_event(@Cancel, *tokens.map(&:event))
      end

    end

    private_constant :Token

    # TODO (pitr-ch 27-Mar-2016): cooperation with mutex, select etc?
    # TODO (pitr-ch 27-Mar-2016): examples (scheduled to be cancelled in 10 sec)
  end

  class Throttle < Synchronization::Object

    safe_initialization!
    private *attr_atomic(:can_run)

    def initialize(max)
      super()
      self.can_run = max
      # TODO (pitr-ch 10-Jun-2016): lockfree gueue is needed
      @Queue       = Queue.new
    end

    def limit(ready = nil, &block)
      # TODO (pitr-ch 11-Jun-2016): triggers should allocate resources when they are to be required
      if block_given?
        block.call(get_event).on_completion! { done }
      else
        get_event
      end
    end

    def done
      while true
        current_can_run = can_run
        if compare_and_set_can_run current_can_run, current_can_run + 1
          @Queue.pop.complete if current_can_run < 0
          return self
        end
      end
    end

    private

    def get_event
      while true
        current_can_run = can_run
        if compare_and_set_can_run current_can_run, current_can_run - 1
          if current_can_run > 0
            return Promises.completed_event
          else
            e = Promises.completable_event
            @Queue.push e
            return e
          end
        end
      end
    end
  end
end
