require 'concurrent/synchronization'
require 'concurrent/atomic/atomic_boolean'
require 'concurrent/atomic/atomic_fixnum'
require 'concurrent/lock_free_stack'
require 'concurrent/concern/logging'
require 'concurrent/errors'

module Concurrent

  # # Promises Framework
  #
  # Unified implementation of futures and promises which combines features of previous `Future`,
  # `Promise`, `IVar`, `Event`, `dataflow`, `Delay`, and `TimerTask` into a single framework. It extensively uses the
  # new synchronization layer to make all the features **non-blocking** and **lock-free**, with the exception of obviously blocking
  # operations like `#wait`, `#value`. It also offers better performance.
  #
  # ## Examples
  # {include:file:examples/promises.out.rb}
  module Promises

    module FactoryMethods
      # User is responsible for completing the event once by {Promises::CompletableEvent#complete}
      # @return [CompletableEvent]
      def completable_event(default_executor = :io)
        CompletableEventPromise.new(default_executor).future
      end

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation begins immediately.
      # @return [Future]
      def future(*args, &task)
        future_on(:io, *args, &task)
      end

      def future_on(default_executor, *args, &task)
        ImmediateEventPromise.new(default_executor).future.then(*args, &task)
      end

      # User is responsible for completing the future once by {Promises::CompletableFuture#success} or {Promises::CompletableFuture#fail}
      # @return [CompletableFuture]
      def completable_future(default_executor = :io)
        CompletableFuturePromise.new(default_executor).future
      end

      # @return [Future] which is already completed
      def completed_future(success, value, reason, default_executor = :io)
        ImmediateFuturePromise.new(default_executor, success, value, reason).future
      end

      # @return [Future] which is already completed in success state with value
      def succeeded_future(value, default_executor = :io)
        completed_future true, value, nil, default_executor
      end

      # @return [Future] which is already completed in failed state with reason
      def failed_future(reason, default_executor = :io)
        completed_future false, nil, reason, default_executor
      end

      # @return [Event] which is already completed
      def completed_event(default_executor = :io)
        ImmediateEventPromise.new(default_executor).event
      end

      # Constructs new Future which will evaluate to the block after
      # requested by calling `#wait`, `#value`, `#value!`, etc. on it or on any of the chained futures.
      # @return [Future]
      def delay(*args, &task)
        delay_on :io, *args, &task
      end

      def delay_on(default_executor, *args, &task)
        DelayPromise.new(default_executor).future.then(*args, &task)
      end

      # Schedules the block to be executed on executor in given intended_time.
      # @param [Numeric, Time] intended_time Numeric => run in `intended_time` seconds. Time => eun on time.
      # @return [Future]
      def schedule(intended_time, *args, &task)
        schedule_on :io, intended_time, *args, &task
      end

      def schedule_on(default_executor, intended_time, *args, &task)
        ScheduledPromise.new(default_executor, intended_time).future.then(*args, &task)
      end

      # Constructs new {Future} which is completed after all futures_and_or_events are complete. Its value is array
      # of dependent future values. If there is an error it fails with the first one. Event does not
      # have a value so it's represented by nil in the array of values.
      # @param [Event] futures_and_or_events
      # @return [Future]
      def zip_futures(*futures_and_or_events)
        zip_futures_on :io, *futures_and_or_events
      end

      def zip_futures_on(default_executor, *futures_and_or_events)
        ZipFuturesPromise.new(futures_and_or_events, default_executor).future
      end

      alias_method :zip, :zip_futures

      # Constructs new {Event} which is completed after all futures_and_or_events are complete
      # (Future is completed when Success or Failed).
      # @param [Event] futures_and_or_events
      # @return [Event]
      def zip_events(*futures_and_or_events)
        zip_events_on :io, *futures_and_or_events
      end

      def zip_events_on(default_executor, *futures_and_or_events)
        ZipEventsPromise.new(futures_and_or_events, default_executor).future
      end

      # Constructs new {Future} which is completed after first of the futures is complete.
      # @param [Event] futures
      # @return [Future]
      def any_complete_future(*futures)
        any_complete_future_on :io, *futures
      end

      def any_complete_future_on(default_executor, *futures)
        AnyCompleteFuturePromise.new(futures, default_executor).future
      end

      alias_method :any, :any_complete_future

      # Constructs new {Future} which becomes succeeded after first of the futures succeedes or
      # failed if all futures fail (reason is last error).
      # @param [Event] futures
      # @return [Future]
      def any_successful_future(*futures)
        any_successful_future_on :io, *futures
      end

      def any_successful_future_on(default_executor, *futures)
        AnySuccessfulFuturePromise.new(futures, default_executor).future
      end

      def any_event(*events)
        any_event_on :io, *events
      end

      def any_event_on(default_executor, *events)
        AnyCompleteEventPromise.new(events, default_executor).event
      end

      # TODO consider adding first(count, *futures)
      # TODO consider adding zip_by(slice, *futures) processing futures in slices
    end

    # Represents an event which will happen in future (will be completed). It has to always happen.
    class Event < Synchronization::Object
      safe_initialization!
      private(*attr_atomic(:internal_state))
      # @!visibility private
      public :internal_state
      include Concern::Logging

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

      # @!visibility private
      class SuccessArray < Success
        def apply(args, block)
          block.call(*value, *args)
        end
      end

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


      # @!visibility private
      PENDING   = Pending.new
      # @!visibility private
      COMPLETED = Success.new(nil)

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

      # @return [:pending, :completed]
      def state
        internal_state.to_sym
      end

      # Is Event/Future pending?
      # @return [Boolean]
      def pending?(state = internal_state)
        !state.completed?
      end

      def unscheduled?
        raise 'unsupported'
      end

      alias_method :incomplete?, :pending?

      # Has the Event been completed?
      # @return [Boolean]
      def completed?(state = internal_state)
        state.completed?
      end

      alias_method :complete?, :completed?

      # Wait until Event is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @return [Event, true, false] self or true/false if timeout is used
      # @!macro [attach] edge.periodical_wait
      #   @note a thread should wait only once! For repeated checking use faster `completed?` check.
      #     If thread waits periodically it will dangerously grow the waiters stack.
      def wait(timeout = nil)
        touch
        result = wait_until_complete(timeout)
        timeout ? result : self
      end

      # @!visibility private
      def touch
        # distribute touch to promise only once
        @Promise.touch if @Touched.make_true
        self
      end

      # @return [Executor] current default executor
      # @see #with_default_executor
      def default_executor
        @DefaultExecutor
      end

      # @yield [success, value, reason] of the parent
      def chain(*args, &callback)
        chain_on @DefaultExecutor, *args, &callback
      end

      def chain_on(executor, *args, &callback)
        ChainPromise.new(self, @DefaultExecutor, executor, args, &callback).future
      end

      alias_method :then, :chain

      def chain_completable(completable_event)
        on_completion! { completable_event.complete_with COMPLETED }
      end

      alias_method :tangle, :chain_completable

      # Zip with future producing new Future
      # @return [Event]
      def zip(other)
        if other.is?(Future)
          ZipFutureEventPromise.new(other, self, @DefaultExecutor).future
        else
          ZipEventEventPromise.new(self, other, @DefaultExecutor).event
        end
      end

      alias_method :&, :zip

      def any(future)
        AnyCompleteEventPromise.new([self, future], @DefaultExecutor).event
      end

      alias_method :|, :any

      # Inserts delay into the chain of Futures making rest of it lazy evaluated.
      # @return [Event]
      def delay
        ZipEventEventPromise.new(self, DelayPromise.new(@DefaultExecutor).event, @DefaultExecutor).event
      end

      # Schedules rest of the chain for execution with specified time or on specified time
      # @return [Event]
      def schedule(intended_time)
        ZipEventEventPromise.new(self,
                                 ScheduledPromise.new(@DefaultExecutor, intended_time).event,
                                 @DefaultExecutor).event
      end

      # @yield [success, value, reason, *args] executed async on `executor` when completed
      # @return self
      def on_completion(*args, &callback)
        on_completion_using @DefaultExecutor, *args, &callback
      end

      def on_completion_using(executor, *args, &callback)
        add_callback :async_callback_on_completion, executor, args, callback
      end

      # @yield [success, value, reason, *args] executed sync when completed
      # @return self
      def on_completion!(*args, &callback)
        add_callback :callback_on_completion, args, callback
      end

      # Changes default executor for rest of the chain
      # @return [Event]
      def with_default_executor(executor)
        EventWrapperPromise.new(self, executor).future
      end

      def to_s
        "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state.to_sym}>"
      end

      def inspect
        "#{to_s[0..-2]} blocks:[#{blocks.map(&:to_s).join(', ')}]>"
      end

      def set(*args, &block)
        raise 'Use CompletableEvent#complete or CompletableFuture#complete instead, ' +
                  'constructed by Concurrent.event or Concurrent.future respectively.'
      end

      # @!visibility private
      def complete_with(state, raise_on_reassign = true)
        if compare_and_set_internal_state(PENDING, state)
          # go to synchronized block only if there were waiting threads
          @Lock.synchronize { @Condition.broadcast } unless @Waiters.value == 0
          call_callbacks
        else
          Concurrent::MultipleAssignmentError.new('Event can be completed only once') if raise_on_reassign
          return nil
        end
        self
      end

      # @!visibility private
      # just for inspection
      # @return [Array<AbstractPromise>]
      def blocks
        @Callbacks.each_with_object([]) do |callback, promises|
          promises.push(*(callback.select { |v| v.is_a? AbstractPromise }))
        end
      end

      # @!visibility private
      # just for inspection
      def callbacks
        @Callbacks.each.to_a
      end

      # @!visibility private
      def add_callback(method, *args)
        if completed?
          call_callback method, *args
        else
          @Callbacks.push [method, *args]
          call_callbacks if completed?
        end
        self
      end

      # @!visibility private
      # only for inspection
      def promise
        @Promise
      end

      # @!visibility private
      # only for inspection
      def touched
        @Touched.value
      end

      # @!visibility private
      # only for debugging inspection
      def waiting_threads
        @Waiters.each.to_a
      end

      private

      # @return [true, false]
      def wait_until_complete(timeout)
        return true if completed?

        @Lock.synchronize do
          @Waiters.increment
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

      def with_async(executor, *args, &block)
        Concurrent.executor(executor).post(*args, &block)
      end

      def async_callback_on_completion(executor, args, callback)
        with_async(executor) { callback_on_completion args, callback }
      end

      def callback_on_completion(args, callback)
        callback.call *args
      end

      def callback_notify_blocked(promise)
        promise.on_done self
      end

      def call_callback(method, *args)
        self.send method, *args
      end

      def call_callbacks
        method, *args = @Callbacks.pop
        while method
          call_callback method, *args
          method, *args = @Callbacks.pop
        end
      end
    end

    # Represents a value which will become available in future. May fail with a reason instead.
    class Future < Event

      # @!method state
      #   @return [:pending, :success, :failed]

      # Has Future been success?
      # @return [Boolean]
      def success?(state = internal_state)
        state.completed? && state.success?
      end

      # Has Future been failed?
      # @return [Boolean]
      def failed?(state = internal_state)
        state.completed? && !state.success?
      end

      # @return [Object, nil] the value of the Future when success, nil on timeout
      # @!macro [attach] edge.timeout_nil
      #   @note If the Future can have value `nil` then it cannot be distinquished from `nil` returned on timeout.
      #     In this case is better to use first `wait` then `value` (or similar).
      # @!macro edge.periodical_wait
      def value(timeout = nil)
        touch
        internal_state.value if wait_until_complete timeout
      end

      # @return [Exception, nil] the reason of the Future's failure
      # @!macro edge.timeout_nil
      # @!macro edge.periodical_wait
      def reason(timeout = nil)
        touch
        internal_state.reason if wait_until_complete timeout
      end

      # @return [Array(Boolean, Object, Exception), nil] triplet of success, value, reason
      # @!macro edge.timeout_nil
      # @!macro edge.periodical_wait
      def result(timeout = nil)
        touch
        internal_state.result if wait_until_complete timeout
      end

      # Wait until Future is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @raise reason on failure
      # @return [Event, true, false] self or true/false if timeout is used
      # @!macro edge.periodical_wait
      def wait!(timeout = nil)
        touch
        result = wait_until_complete!(timeout)
        timeout ? result : self
      end

      # Wait until Future is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @raise reason on failure
      # @return [Object, nil]
      # @!macro edge.timeout_nil
      # @!macro edge.periodical_wait
      def value!(timeout = nil)
        touch
        internal_state.value if wait_until_complete! timeout
      end

      # @example allows failed Future to be risen
      #   raise Concurrent.future.fail
      def exception(*args)
        raise 'obligation is not failed' unless failed?
        reason = internal_state.reason
        if reason.is_a?(::Array)
          reason.each { |e| log ERROR, 'Promises::Future', e }
          Concurrent::Error.new 'multiple exceptions, inspect log'
        else
          reason.exception(*args)
        end
      end

      # @yield [value, *args] executed only on parent success
      # @return [Future] new
      def then(*args, &callback)
        then_on @DefaultExecutor, *args, &callback
      end

      def then_on(executor, *args, &callback)
        ThenPromise.new(self, @DefaultExecutor, executor, args, &callback).future
      end

      def chain_completable(completable_future)
        on_completion! { completable_future.complete_with internal_state }
      end

      alias_method :tangle, :chain_completable

      # @yield [reason] executed only on parent failure
      # @return [Future]
      def rescue(*args, &callback)
        rescue_on @DefaultExecutor, *args, &callback
      end

      def rescue_on(executor, *args, &callback)
        RescuePromise.new(self, @DefaultExecutor, executor, args, &callback).future
      end

      # zips with the Future in the value
      # @example
      #   Concurrent.future { Concurrent.future { 1 } }.flat.value # => 1
      def flat(level = 1)
        FlatPromise.new(self, level, @DefaultExecutor).future
      end

      # @return [Future] which has first completed value from futures
      def any(future)
        AnyCompleteFuturePromise.new([self, future], @DefaultExecutor).future
      end

      # Inserts delay into the chain of Futures making rest of it lazy evaluated.
      # @return [Future]
      def delay
        ZipFutureEventPromise.new(self, DelayPromise.new(@DefaultExecutor).future, @DefaultExecutor).future
      end

      # Schedules rest of the chain for execution with specified time or on specified time
      # @return [Future]
      def schedule(intended_time)
        chain do
          ZipFutureEventPromise.new(self,
                                    ScheduledPromise.new(@DefaultExecutor, intended_time).event,
                                    @DefaultExecutor).future
        end.flat
      end

      # Changes default executor for rest of the chain
      # @return [Future]
      def with_default_executor(executor)
        FutureWrapperPromise.new(self, executor).future
      end

      # Zip with future producing new Future
      # @return [Future]
      def zip(other)
        if other.is_a?(Future)
          ZipFutureFuturePromise.new(self, other, @DefaultExecutor).future
        else
          ZipFutureEventPromise.new(self, other, @DefaultExecutor).future
        end
      end

      alias_method :&, :zip

      alias_method :|, :any

      # @yield [value] executed async on `executor` when success
      # @return self
      def on_success(*args, &callback)
        on_success_using @DefaultExecutor, *args, &callback
      end

      def on_success_using(executor, *args, &callback)
        add_callback :async_callback_on_success, executor, args, callback
      end

      # @yield [reason] executed async on `executor` when failed?
      # @return self
      def on_failure(*args, &callback)
        on_failure_using @DefaultExecutor, *args, &callback
      end

      def on_failure_using(executor, *args, &callback)
        add_callback :async_callback_on_failure, executor, args, callback
      end

      # @yield [value] executed sync when success
      # @return self
      def on_success!(*args, &callback)
        add_callback :callback_on_success, args, callback
      end

      # @yield [reason] executed sync when failed?
      # @return self
      def on_failure!(*args, &callback)
        add_callback :callback_on_failure, args, callback
      end

      # @!visibility private
      def complete_with(state, raise_on_reassign = true)
        if compare_and_set_internal_state(PENDING, state)
          # go to synchronized block only if there were waiting threads
          @Lock.synchronize { @Condition.broadcast } unless @Waiters.value == 0
          call_callbacks state
        else
          if raise_on_reassign
            # print otherwise hidden error
            log ERROR, 'Promises::Future', reason if reason
            log ERROR, 'Promises::Future', state.reason if state.reason

            raise(Concurrent::MultipleAssignmentError.new(
                "Future can be completed only once. Current result is #{result}, " +
                    "trying to set #{state.result}"))
          end
          return false
        end
        self
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

      # @!visibility private
      def apply(args, block)
        internal_state.apply args, block
      end

      private

      def wait_until_complete!(timeout = nil)
        result = wait_until_complete(timeout)
        raise self if failed?
        result
      end

      def call_callbacks(state)
        method, *args = @Callbacks.pop
        while method
          call_callback method, state, *args
          method, *args = @Callbacks.pop
        end
      end

      def call_callback(method, state, *args)
        self.send method, state, *args
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

      def callback_notify_blocked(state, promise)
        super(promise)
      end

      def async_callback_on_completion(state, executor, args, callback)
        with_async(executor, state, args, callback) do |st, ar, cb|
          callback_on_completion st, ar, cb
        end
      end
    end

    # A Event which can be completed by user.
    class CompletableEvent < Event
      # Complete the Event, `raise` if already completed
      def complete(raise_on_reassign = true)
        complete_with COMPLETED, raise_on_reassign
      end

      def with_hidden_completable
        EventWrapperPromise.new(self, @DefaultExecutor).event
      end
    end

    # A Future which can be completed by user.
    class CompletableFuture < Future
      # Complete the future with triplet od `success`, `value`, `reason`
      # `raise` if already completed
      # return [self]
      def complete(success, value, reason, raise_on_reassign = true)
        complete_with(success ? Success.new(value) : Failed.new(reason), raise_on_reassign)
      end

      # Complete the future with value
      # return [self]
      def success(value)
        promise.success(value)
      end

      # Try to complete the future with value
      # return [self]
      def try_success(value)
        promise.try_success(value)
      end

      # Fail the future with reason
      # return [self]
      def fail(reason = StandardError.new)
        promise.fail(reason)
      end

      # Try to fail the future with reason
      # return [self]
      def try_fail(reason = StandardError.new)
        promise.try_fail(reason)
      end

      # Evaluate the future to value if there is an exception the future fails with it
      # return [self]
      def evaluate_to(*args, &block)
        promise.evaluate_to(*args, block)
      end

      # Evaluate the future to value if there is an exception the future fails with it
      # @raise the exception
      # return [self]
      def evaluate_to!(*args, &block)
        promise.evaluate_to!(*args, block)
      end

      def with_hidden_completable
        FutureWrapperPromise.new(self, @DefaultExecutor).future
      end
    end

    # @abstract
    class AbstractPromise < Synchronization::Object
      safe_initialization!
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
        complete_with Future::Success.new(block.call(*args))
      rescue StandardError => error
        complete_with Future::Failed.new(error)
      rescue Exception => error
        log(ERROR, 'Promises::Future', error)
        complete_with Future::Failed.new(error)
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

      # Set the `Future` to a value and wake or notify all threads waiting on it.
      #
      # @param [Object] value the value to store in the `Future`
      # @raise [Concurrent::MultipleAssignmentError] if the `Future` has already been set or otherwise completed
      # @return [Future]
      def success(value)
        complete_with Future::Success.new(value)
      end

      def try_success(value)
        !!complete_with(Future::Success.new(value), false)
      end

      # Set the `Future` to failed due to some error and wake or notify all threads waiting on it.
      #
      # @param [Object] reason for the failure
      # @raise [Concurrent::MultipleAssignmentError] if the `Future` has already been set or otherwise completed
      # @return [Future]
      def fail(reason = StandardError.new)
        complete_with Future::Failed.new(reason)
      end

      def try_fail(reason = StandardError.new)
        !!complete_with(Future::Failed.new(reason), false)
      end

      public :evaluate_to

      # @return [Future]
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
        super Event.new(self, default_executor).complete_with(Event::COMPLETED)
      end
    end

    class ImmediateFuturePromise < InnerPromise
      def initialize(default_executor, success, value, reason)
        super Future.new(self, default_executor).
            complete_with(success ? Future::Success.new(value) : Future::Failed.new(reason))
      end
    end

    class FlatPromise < BlockedPromise

      # !visibility private
      def blocked_by
        @BlockedBy.each.to_a
      end

      private

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
            value.touch if self.future.touched
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

      def initialize(blocked_by_future, levels, default_executor)
        raise ArgumentError, 'levels has to be higher than 0' if levels < 1
        super Future.new(self, default_executor), blocked_by_future, 1 + levels
      end

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

    class ZipEventEventPromise < BlockedPromise
      def initialize(event1, event2, default_executor)
        super Event.new(self, default_executor), [event1, event2], 2
      end

      def on_completable(done_future)
        complete_with Event::COMPLETED
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
                                      Future::SuccessArray.new([value1, value2])
                                    else
                                      Future::PartiallyFailed.new([value1, value2], [reason1, reason2])
                                    end
        complete_with new_state
      end
    end

    class EventWrapperPromise < BlockedPromise
      def initialize(event, default_executor)
        super Event.new(self, default_executor), [event], 1
      end

      def on_completable(done_future)
        complete_with Event::COMPLETED
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
          complete_with Future::SuccessArray.new(values)
        else
          complete_with Future::PartiallyFailed.new(values, reasons)
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
        complete_with Event::COMPLETED
      end
    end

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
        complete_with Event::COMPLETED, false
      end
    end

    class AnySuccessfulFuturePromise < AnyCompleteFuturePromise

      private

      def completable?(countdown, future)
        future.success? || super(countdown, future)
      end
    end

    class DelayPromise < InnerPromise
      def touch
        @Future.complete_with Event::COMPLETED
      end

      private

      def initialize(default_executor)
        super Event.new(self, default_executor)
      end
    end

    # will be evaluated to task in intended_time
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
          @Future.complete_with Event::COMPLETED
        end
      end
    end

    extend FactoryMethods

    private_constant :AbstractPromise, :CompletableEventPromise, :CompletableFuturePromise,
                     :InnerPromise, :BlockedPromise, :BlockedTaskPromise, :ThenPromise,
                     :RescuePromise, :ChainPromise, :ImmediateEventPromise,
                     :ImmediateFuturePromise, :FlatPromise, :ZipEventEventPromise,
                     :ZipFutureEventPromise, :ZipFutureFuturePromise, :EventWrapperPromise,
                     :FutureWrapperPromise, :ZipFuturesPromise, :ZipEventsPromise,
                     :AnyCompleteFuturePromise, :AnySuccessfulFuturePromise, :DelayPromise, :ScheduledPromise

  end
end

# TODO when value is requested the current thread may evaluate the tasks to get the value for performance reasons it may not evaluate :io though
# TODO try work stealing pool, each thread has it's own queue
