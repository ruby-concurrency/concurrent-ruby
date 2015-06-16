require 'concurrent' # TODO do not require whole concurrent gem
require 'concurrent/edge/lock_free_stack'


# @note different name just not to collide for now
module Concurrent
  module Edge

    # Provides edge features, which will be added to or replace features in main gem.
    #
    # Contains new unified implementation of Futures and Promises which combines Features of previous `Future`,
    # `Promise`, `IVar`, `Event`, `Probe`, `dataflow`, `Delay`, `TimerTask` into single framework. It uses extensively
    # new synchronization layer to make all the paths lock-free with exception of blocking threads on `#wait`.
    # It offers better performance and does not block threads (exception being #wait and similar methods where it's
    # intended).
    #
    # ## Examples
    # {include:file:examples/edge_futures.out.rb}
    #
    # @!macro edge_warning
    module FutureShortcuts
      # User is responsible for completing the event once by {Edge::CompletableEvent#complete}
      # @return [CompletableEvent]
      def event(default_executor = :io)
        CompletableEventPromise.new(default_executor).future
      end

      # @overload future(default_executor = :io, &task)
      #   Constructs new Future which will be completed after block is evaluated on executor. Evaluation begins immediately.
      #   @return [Future]
      # @overload future(default_executor = :io)
      #   User is responsible for completing the future once by {Edge::CompletableFuture#success} or {Edge::CompletableFuture#fail}
      #   @return [CompletableFuture]
      def future(*args, &task)
        future_on :io, *args, &task
      end

      def future_on(default_executor, *args, &task)
        if task
          ImmediatePromise.new(default_executor, *args).future.then(&task)
        else
          CompletableFuturePromise.new(default_executor).future
        end
      end

      alias_method :async, :future

      # Constructs new Future which will evaluate to the block after
      # requested by calling `#wait`, `#value`, `#value!`, etc. on it or on any of the chained futures.
      # @return [Future]
      def delay(*args, &task)
        delay_on :io, *args, &task
      end

      # @return [Future]
      def delay_on(default_executor, *args, &task)
        Delay.new(default_executor, *args).future.then(&task)
      end

      # Schedules the block to be executed on executor in given intended_time.
      # @param [Numeric, Time] intended_time Numeric => run in `intended_time` seconds. Time => eun on time.
      # @return [Future]
      def schedule(intended_time, *args, &task)
        schedule_on :io, intended_time, *args, &task
      end

      # @return [Future]
      def schedule_on(default_executor, intended_time, *args, &task)
        ScheduledPromise.new(default_executor, intended_time, *args).future.then(&task)
      end

      # Constructs new {Future} which is completed after all futures are complete. Its value is array
      # of dependent future values. If there is an error it fails with the first one.
      # @param [Event] futures
      # @return [Future]
      def zip(*futures)
        AllPromise.new(futures, :io).future
      end

      # Constructs new {Future} which is completed after first of the futures is complete.
      # @param [Event] futures
      # @return [Future]
      def any(*futures)
        AnyPromise.new(futures, :io).future
      end

      # only proof of concept
      # @return [Future]
      def select(*channels)
        probe = future
        channels.each { |ch| ch.select probe }
        probe
      end

      # post job on :fast executor
      # @return [true, false]
      def post!(*args, &job)
        post_on(:fast, *args, &job)
      end

      # post job on :io executor
      # @return [true, false]
      def post(*args, &job)
        post_on(:io, *args, &job)
      end

      # post job on executor
      # @return [true, false]
      def post_on(executor, *args, &job)
        Concurrent.executor(executor).post *args, &job
      end

      # TODO add first(futures, count=count)
      # TODO allow to to have a zip point for many futures and process them in batches by 10
    end

    extend FutureShortcuts
    include FutureShortcuts

    # Represents an event which will happen in future (will be completed). It has to always happen.
    class Event < Synchronization::Object
      include Concern::Deprecation

      class State
        def completed?
          raise NotImplementedError
        end

        def to_sym
          raise NotImplementedError
        end
      end

      class Pending < State
        def completed?
          false
        end

        def to_sym
          :pending
        end
      end

      class Completed < State
        def completed?
          true
        end

        def to_sym
          :completed
        end
      end

      PENDING   = Pending.new
      COMPLETED = Completed.new

      def initialize(promise, default_executor)
        @Promise         = promise
        @DefaultExecutor = default_executor
        @Touched         = AtomicBoolean.new(false)
        @Callbacks       = LockFreeStack.new
        @Waiters         = LockFreeStack.new
        @State           = AtomicReference.new PENDING
        super()
        ensure_ivar_visibility!
      end

      # @return [:pending, :completed]
      def state
        @State.get.to_sym
      end

      # Is Event/Future pending?
      # @return [Boolean]
      def pending?(state = @State.get)
        !state.completed?
      end

      def unscheduled?
        raise 'unsupported'
      end

      alias_method :incomplete?, :pending?

      # Has the Event been completed?
      # @return [Boolean]
      def completed?(state = @State.get)
        state.completed?
      end

      alias_method :complete?, :completed?

      # Wait until Event is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @return [Event] self
      def wait(timeout = nil)
        touch
        wait_until_complete timeout
        self
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
      def chain(executor = nil, &callback)
        ChainPromise.new(self, @DefaultExecutor, executor || @DefaultExecutor, &callback).future
      end

      alias_method :then, :chain

      # TODO take block optionally
      # Zip with futures producing new Future
      # @return [Future]
      def zip(*futures)
        AllPromise.new([self, *futures], @DefaultExecutor).future
      end

      alias_method :&, :zip

      # Inserts delay into the chain of Futures making rest of it lazy evaluated.
      # @return [Future]
      def delay
        zip(Delay.new(@DefaultExecutor).future)
      end

      # Schedules rest of the chain for execution with specified time or on specified time
      # @return [Future]
      def schedule(intended_time)
        chain { ScheduledPromise.new(@DefaultExecutor, intended_time).event.zip(self) }.flat
      end

      # Zips with selected value form the suplied channels
      # @return [Future]
      def then_select(*channels)
        self.zip(Concurrent.select(*channels))
      end

      # @yield [success, value, reason] executed async on `executor` when completed
      # @return self
      def on_completion(executor = nil, &callback)
        add_callback :pr_async_callback_on_completion, executor || @DefaultExecutor, callback
      end

      # @yield [success, value, reason] executed sync when completed
      # @return self
      def on_completion!(&callback)
        add_callback :pr_callback_on_completion, callback
      end

      # Changes default executor for rest of the chain
      # @return [Future]
      def with_default_executor(executor)
        AllPromise.new([self], executor).future
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
      def complete(raise_on_reassign = true)
        if complete_state
          # go to synchronized block only if there were waiting threads
          synchronize { ns_broadcast } if @Waiters.clear
          call_callbacks
        else
          Concurrent::MultipleAssignmentError.new('multiple assignment') if raise_on_reassign
          return false
        end
        self
      end

      # @!visibility private
      # just for inspection
      # @return [Array<AbstractPromise>]
      def blocks
        @Callbacks.each_with_object([]) do |callback, promises|
          promises.push *callback.select { |v| v.is_a? AbstractPromise }
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

      # only for debugging inspection
      def waiting_threads
        @Waiters.each.to_a
      end

      private

      def wait_until_complete(timeout)
        while true
          last_waiter = @Waiters.peek # waiters' state before completion
          break if completed?

          # synchronize so it cannot be signaled before it waits
          synchronize do
            # ok only if completing thread did not start signaling
            next unless @Waiters.compare_and_push last_waiter, Thread.current
            ns_wait_until(timeout) { completed? }
          end
          break
        end
        self
      end

      def complete_state
        COMPLETED if @State.compare_and_set(PENDING, COMPLETED)
      end

      def pr_with_async(executor, *args, &block)
        Concurrent.post_on(executor, *args, &block)
      end

      def pr_async_callback_on_completion(executor, callback)
        pr_with_async(executor) { pr_callback_on_completion callback }
      end

      def pr_callback_on_completion(callback)
        callback.call
      end

      def pr_callback_notify_blocked(promise)
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
      class CompletedWithResult < Completed
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
      end

      class Success < CompletedWithResult
        def initialize(value)
          @Value = value
        end

        def success?
          true
        end

        def apply(block)
          block.call value
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

      class SuccessArray < Success
        def apply(block)
          block.call *value
        end
      end

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

        def apply(block)
          block.call reason
        end
      end

      # @!method state
      #   @return [:pending, :success, :failed]

      # Has Future been success?
      # @return [Boolean]
      def success?(state = @State.get)
        state.success?
      end

      def fulfilled?
        deprecated_method 'fulfilled?', 'success?'
        success?
      end

      # Has Future been failed?
      # @return [Boolean]
      def failed?(state = @State.get)
        !success?(state)
      end

      def rejected?
        deprecated_method 'rejected?', 'failed?'
        failed?
      end

      # @return [Object] the value of the Future when success
      def value(timeout = nil)
        touch
        wait_until_complete timeout
        @State.get.value
      end

      # @return [Exception] the reason of the Future's failure
      def reason(timeout = nil)
        touch
        wait_until_complete timeout
        @State.get.reason
      end

      # @return [Array(Boolean, Object, Exception)] triplet of success, value, reason
      def result(timeout = nil)
        touch
        wait_until_complete timeout
        @State.get.result
      end

      # Wait until Future is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @raise reason on failure
      # @return [Event] self
      def wait!(timeout = nil)
        touch
        wait_until_complete! timeout
      end

      # Wait until Future is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @raise reason on failure
      # @return [Object]
      def value!(timeout = nil)
        touch
        wait_until_complete!(timeout)
        @State.get.value
      end

      # @example allows failed Future to be risen
      #   raise Concurrent.future.fail
      def exception(*args)
        touch
        raise 'obligation is not failed' unless failed?
        @State.get.reason.exception(*args)
      end

      # @yield [value] executed only on parent success
      # @return [Future]
      def then(executor = nil, &callback)
        ThenPromise.new(self, @DefaultExecutor, executor || @DefaultExecutor, &callback).future
      end

      # Asks the actor with its value.
      # @return [Future] new future with the response form the actor
      def then_ask(actor)
        self.then { |v| actor.ask(v) }.flat
      end

      # @yield [reason] executed only on parent failure
      # @return [Future]
      def rescue(executor = nil, &callback)
        RescuePromise.new(self, @DefaultExecutor, executor || @DefaultExecutor, &callback).future
      end

      # zips with the Future in the value
      # @example
      #   Concurrent.future { Concurrent.future { 1 } }.flat.vale # => 1
      def flat(level = 1)
        FlattingPromise.new(self, level, @DefaultExecutor).future
      end

      # @return [Future] which has first completed value from futures
      def any(*futures)
        AnyPromise.new([self, *futures], @DefaultExecutor).future
      end

      alias_method :|, :any

      # only proof of concept
      def then_push(channel)
        on_success { |value| channel.push value } # FIXME it's blocking for now
      end

      # @yield [value] executed async on `executor` when success
      # @return self
      def on_success(executor = nil, &callback)
        add_callback :pr_async_callback_on_success, executor || @DefaultExecutor, callback
      end

      # @yield [reason] executed async on `executor` when failed?
      # @return self
      def on_failure(executor = nil, &callback)
        add_callback :pr_async_callback_on_failure, executor || @DefaultExecutor, callback
      end

      # @yield [value] executed sync when success
      # @return self
      def on_success!(&callback)
        add_callback :pr_callback_on_success, callback
      end

      # @yield [reason] executed sync when failed?
      # @return self
      def on_failure!(&callback)
        add_callback :pr_callback_on_failure, callback
      end

      # @!visibility private
      def complete(success, value, reason, raise_on_reassign = true)
        if (new_state = complete_state success, value, reason)
          @Waiters.clear
          synchronize { ns_broadcast }
          call_callbacks new_state
        else
          raise reason || Concurrent::MultipleAssignmentError.new('multiple assignment') if raise_on_reassign
          return false
        end
        self
      end

      # @!visibility private
      def add_callback(method, *args)
        state = @State.get
        if completed?(state)
          call_callback method, state, *args
        else
          @Callbacks.push [method, *args]
          state = @State.get
          # take back if it was completed in the meanwhile
          call_callbacks state if completed?(state)
        end
        self
      end

      # @!visibility private
      def apply(block)
        @State.get.apply block
      end

      private

      def wait_until_complete!(timeout = nil)
        wait_until_complete(timeout)
        raise self if failed?
        self
      end

      def complete_state(success, value, reason)
        new_state = if success
                      if value.is_a?(Array)
                        SuccessArray.new(value)
                      else
                        Success.new(value)
                      end
                    else
                      Failed.new(reason)
                    end
        new_state if @State.compare_and_set(PENDING, new_state)
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

      def pr_async_callback_on_success(state, executor, callback)
        pr_with_async(executor, state, callback) do |state, callback|
          pr_callback_on_success state, callback
        end
      end

      def pr_async_callback_on_failure(state, executor, callback)
        pr_with_async(executor, state, callback) do |state, callback|
          pr_callback_on_failure state, callback
        end
      end

      def pr_callback_on_success(state, callback)
        state.apply callback if state.success?
      end

      def pr_callback_on_failure(state, callback)
        state.apply callback unless state.success?
      end

      def pr_callback_on_completion(state, callback)
        callback.call state.result
      end

      def pr_callback_notify_blocked(state, promise)
        super(promise)
      end

      def pr_async_callback_on_completion(state, executor, callback)
        pr_with_async(executor, state, callback) do |state, callback|
          pr_callback_on_completion state, callback
        end
      end

    end

    # A Event which can be completed by user.
    class CompletableEvent < Event
      # Complete the Event, `raise` if already completed
      def complete(raise_on_reassign = true)
        super raise_on_reassign
      end

      def hide_completable
        Concurrent.zip(self)
      end
    end

    # A Future which can be completed by user.
    class CompletableFuture < Future
      # Complete the future with triplet od `success`, `value`, `reason`
      # `raise` if already completed
      # return [self]
      def complete(success, value, reason, raise_on_reassign = true)
        super success, value, reason, raise_on_reassign
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

      def hide_completable
        Concurrent.zip(self)
      end
    end

    # TODO modularize blocked_by and notify blocked

    # @abstract
    # @!visibility private
    class AbstractPromise < Synchronization::Object
      def initialize(future)
        @Future = future
        ensure_ivar_visibility!
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

      def complete(*args)
        @Future.complete(*args)
      end

      # @return [Future]
      def evaluate_to(*args, block)
        complete true, block.call(*args), nil
      rescue => error
        complete false, nil, error
      end
    end

    # @!visibility private
    class CompletableEventPromise < AbstractPromise
      public :complete

      def initialize(default_executor)
        super CompletableEvent.new(self, default_executor)
      end
    end

    # @!visibility private
    class CompletableFuturePromise < AbstractPromise
      # TODO consider to allow being blocked_by

      def initialize(default_executor)
        super CompletableFuture.new(self, default_executor)
      end

      # Set the `Future` to a value and wake or notify all threads waiting on it.
      #
      # @param [Object] value the value to store in the `Future`
      # @raise [Concurrent::MultipleAssignmentError] if the `Future` has already been set or otherwise completed
      # @return [Future]
      def success(value)
        complete(true, value, nil)
      end

      def try_success(value)
        complete(true, value, nil, false)
      end

      # Set the `Future` to failed due to some error and wake or notify all threads waiting on it.
      #
      # @param [Object] reason for the failure
      # @raise [Concurrent::MultipleAssignmentError] if the `Future` has already been set or otherwise completed
      # @return [Future]
      def fail(reason = StandardError.new)
        complete(false, nil, reason)
      end

      def try_fail(reason = StandardError.new)
        !!complete(false, nil, reason, false)
      end

      public :complete
      public :evaluate_to

      # @return [Future]
      def evaluate_to!(*args, block)
        evaluate_to(*args, block).wait!
      end
    end

    # @abstract
    # @!visibility private
    class InnerPromise < AbstractPromise
    end

    # @abstract
    # @!visibility private
    class BlockedPromise < InnerPromise
      def initialize(future, blocked_by_futures, countdown, &block)
        initialize_blocked_by(blocked_by_futures)
        @Countdown = AtomicFixnum.new countdown

        super(future)
        @BlockedBy.each { |future| future.add_callback :pr_callback_notify_blocked, self }
      end

      # @api private
      def on_done(future)
        countdown   = process_on_done(future)
        completable = completable?(countdown)

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
        @BlockedBy = Array(blocked_by_futures)
      end

      def clear_blocked_by!
        # not synchronized because we do not care when this change propagates
        @BlockedBy = []
        nil
      end

      # @return [true,false] if completable
      def completable?(countdown)
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
    # @!visibility private
    class BlockedTaskPromise < BlockedPromise
      def initialize(blocked_by_future, default_executor, executor, &task)
        raise ArgumentError, 'no block given' unless block_given?
        @Executor = executor
        @Task     = task
        super Future.new(self, default_executor), blocked_by_future, 1
      end

      def executor
        @Executor
      end
    end

    # @!visibility private
    class ThenPromise < BlockedTaskPromise
      private

      def initialize(blocked_by_future, default_executor, executor, &task)
        raise ArgumentError, 'only Future can be appended with then' unless blocked_by_future.is_a? Future
        super blocked_by_future, default_executor, executor, &task
      end

      def on_completable(done_future)
        if done_future.success?
          Concurrent.post_on(@Executor, done_future, @Task) do |done_future, task|
            evaluate_to lambda { done_future.apply task }
          end
        else
          complete false, nil, done_future.reason
        end
      end
    end

    # @!visibility private
    class RescuePromise < BlockedTaskPromise
      private

      def initialize(blocked_by_future, default_executor, executor, &task)
        raise ArgumentError, 'only Future can be rescued' unless blocked_by_future.is_a? Future
        super blocked_by_future, default_executor, executor, &task
      end

      def on_completable(done_future)
        if done_future.failed?
          Concurrent.post_on(@Executor, done_future.reason, @Task) { |reason, task| evaluate_to reason, task }
        else
          complete true, done_future.value, nil
        end
      end
    end

    # @!visibility private
    class ChainPromise < BlockedTaskPromise
      private

      def on_completable(done_future)
        if Future === done_future
          Concurrent.post_on(@Executor, done_future, @Task) { |future, task| evaluate_to *future.result, task }
        else
          Concurrent.post_on(@Executor, @Task) { |task| evaluate_to task }
        end
      end
    end

    # will be immediately completed
    # @!visibility private
    class ImmediatePromise < InnerPromise
      def initialize(default_executor, *args)
        super(if args.empty?
                Event.new(self, default_executor).complete
              else
                Future.new(self, default_executor).complete(true, args, nil)
              end)
      end
    end

    # @!visibility private
    class FlattingPromise < BlockedPromise

      # !visibility private
      def blocked_by
        @BlockedBy.each.to_a
      end

      private

      def process_on_done(future)
        countdown = super(future)
        value     = future.value!
        if countdown.nonzero?
          case value
          when Future
            @BlockedBy.push value
            value.add_callback :pr_callback_notify_blocked, self
            @Countdown.value
          when Event
            raise TypeError, 'cannot flatten to Event'
          else
            raise TypeError, "returned value #{value.inspect} is not a Future"
          end
        end
        countdown
      end

      def initialize(blocked_by_future, levels, default_executor)
        raise ArgumentError, 'levels has to be higher than 0' if levels < 1
        blocked_by_future.is_a? Future or
            raise ArgumentError, 'only Future can be flatten'
        super Future.new(self, default_executor), blocked_by_future, 1 + levels
      end

      def initialize_blocked_by(blocked_by_future)
        @BlockedBy = LockFreeStack.new.push(blocked_by_future)
      end

      def on_completable(done_future)
        complete *done_future.result
      end

      def clear_blocked_by!
        @BlockedBy.clear
        nil
      end
    end

    # @!visibility private
    class AllPromise < BlockedPromise

      private

      def initialize(blocked_by_futures, default_executor)
        klass = Event
        blocked_by_futures.each do |f|
          if f.is_a?(Future)
            if klass == Event
              klass = Future
              break
            end
          end
        end

        # noinspection RubyArgCount
        super(klass.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)
      end

      def on_completable(done_future)
        all_success = true
        values      = []
        reasons     = []

        blocked_by.each do |future|
          next unless future.is_a?(Future)
          success, value, reason = future.result

          unless success
            all_success = false
          end

          values << value
          reasons << reason
        end

        if all_success
          if values.empty?
            complete
          else
            complete(true, values.size == 1 ? values.first : values, nil)
          end
        else
          # TODO what about other reasons?
          complete(false, nil, reasons.compact.first)
        end
      end
    end

    # @!visibility private
    class AnyPromise < BlockedPromise

      private

      def initialize(blocked_by_futures, default_executor)
        blocked_by_futures.all? { |f| f.is_a? Future } or
            raise ArgumentError, 'accepts only Futures not Events'
        super(Future.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)
      end

      def completable?(countdown)
        true
      end

      def on_completable(done_future)
        complete *done_future.result, false
      end
    end

    # @!visibility private
    class Delay < InnerPromise
      def touch
        if @Args.empty?
          @Future.complete
        else
          @Future.complete(true, @Args, nil)
        end
      end

      private

      def initialize(default_executor, *args)
        @Args = args
        super(if args.empty?
                Event.new(self, default_executor)
              else
                Future.new(self, default_executor)
              end)
      end
    end

    # will be evaluated to task in intended_time
    # @!visibility private
    class ScheduledPromise < InnerPromise
      def intended_time
        @IntendedTime
      end

      def inspect
        "#{to_s[0..-2]} intended_time:[#{@IntendedTime}}>"
      end

      private

      def initialize(default_executor, intended_time, *args)
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

        use_event = args.empty?
        super(if use_event
                Event.new(self, default_executor)
              else
                Future.new(self, default_executor)
              end)

        Concurrent.global_timer_set.post(in_seconds, *args) do |*args|
          if use_event
            @Future.complete
          else
            @Future.complete(true, args, nil)
          end
        end
      end
    end

    # proof of concept
    class Channel < Synchronization::Object
      # TODO make lock free
      def initialize
        super
        @ProbeSet = Concurrent::Channel::WaitableList.new
        ensure_ivar_visibility!
      end

      def probe_set_size
        @ProbeSet.size
      end

      def push(value)
        until @ProbeSet.take.try_success([value, self])
        end
      end

      def pop
        select(Concurrent.future)
      end

      def select(probe)
        @ProbeSet.put(probe)
        probe
      end

      def inspect
        to_s
      end
    end
  end

  extend Edge::FutureShortcuts
  include Edge::FutureShortcuts
end
