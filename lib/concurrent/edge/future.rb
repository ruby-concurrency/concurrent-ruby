require 'concurrent' # TODO do not require whole concurrent gem
require 'concurrent/edge/lock_free_stack'

# TODO support Dereferencable ?
# TODO behaviour with Interrupt exceptions is undefined, use Signal.trap to avoid issues

# @note different name just not to collide for now
module Concurrent

  # Provides edge features, which will be added to or replace features in main gem.
  #
  # Contains new unified implementation of Futures and Promises which combines Features of previous `Future`,
  # `Promise`, `IVar`, `Probe`, `dataflow`, `Delay`, `TimerTask` into single framework. It uses extensively
  # new synchronization layer to make all the paths lock-free with exception of blocking threads on `#wait`.
  # It offers better performance and does not block threads (exception being #wait and similar methods where it's
  # intended).
  #
  # ## Examples
  # {include:file:examples/edge_futures.out.rb}.
  module Edge

    module FutureShortcuts
      # User is responsible for completing the event once.
      # @return [CompletableEvent]
      def event(default_executor = :io)
        CompletableEventPromise.new(default_executor).future
      end

      # @overload future(default_executor = :io, &task)
      #   Constructs new Future which will be completed after block is evaluated on executor. Evaluation begins immediately.
      #   @return [Future]
      #   @note FIXME allow to pass in variables as Thread.new(args) {|args| _ } does
      # @overload future(default_executor = :io)
      #   User is responsible for completing the future once.
      #   @return [CompletableFuture]
      def future(default_executor = :io, &task)
        if task
          ImmediatePromise.new(default_executor).event.chain(&task)
        else
          CompletableFuturePromise.new(default_executor).future
        end
      end

      alias_method :async, :future

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation is delayed until
      # requested by `#wait`, `#value`, `#value!`, etc.
      # @return [Delay]
      def delay(default_executor = :io, &task)
        Delay.new(default_executor).event.chain(&task)
      end

      # Schedules the block to be executed on executor in given intended_time.
      # @return [Future]
      def schedule(intended_time, default_executor = :io, &task)
        ScheduledPromise.new(intended_time, default_executor).future.chain(&task)
      end

      # fails on first error
      # does not block a thread
      # @return [Future]
      def zip(*futures)
        AllPromise.new(futures).future
      end

      def any(*futures)
        AnyPromise.new(futures).future
      end

      def post!(*args, &job)
        post_on(:fast, *args, &job)
      end

      def post(*args, &job)
        post_on(:io, *args, &job)
      end

      def post_on(executor, *args, &job)
        Concurrent.executor(executor).post *args, &job
      end

      # TODO add first(futures, count=count)
      # TODO allow to to have a zip point for many futures and process them in batches by 10
    end

    extend FutureShortcuts
    include FutureShortcuts

    class Event < Synchronization::Object
      extend FutureShortcuts

      def initialize(promise, default_executor = :io)
        @Promise         = promise
        @DefaultExecutor = default_executor
        @Touched         = AtomicBoolean.new(false)
        @Callbacks       = LockFreeStack.new
        @Waiters         = LockFreeStack.new
        @State           = AtomicReference.new :pending
        super()
        ensure_ivar_visibility!
      end

      def state
        @State.get
      end

      # Is Future still pending?
      # @return [Boolean]
      def pending?(state = self.state)
        state == :pending
      end

      alias_method :incomplete?, :pending?

      # Is Future still completed?
      # @return [Boolean]
      def completed?(state = self.state)
        state == :completed
      end

      # wait until Obligation is #complete?
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

      def default_executor
        @DefaultExecutor
      end

      # @yield [success, value, reason] of the parent
      def chain(executor = nil, &callback)
        ChainPromise.new(self, @DefaultExecutor, executor || @DefaultExecutor, &callback).future
      end

      alias_method :then, :chain

      # TODO take block optionally
      def zip(*futures)
        AllPromise.new([self, *futures], @DefaultExecutor).future
      end

      alias_method :&, :zip

      def delay
        zip(Delay.new(@DefaultExecutor).future)
      end

      def schedule(intended_time)
        chain { ScheduledPromise.new(intended_time).future.zip(self) }.flat
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

      def with_default_executor(executor = @DefaultExecutor)
        AllPromise.new([self], executor).future
      end

      def to_s
        "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state}>"
      end

      def inspect
        "#{to_s[0..-2]} blocks:[#{blocks.map(&:to_s).join(', ')}]>"
      end

      # @!visibility private
      def complete(raise = true)
        if complete_state
          # go to synchronized block only if there were waiting threads
          synchronize { ns_broadcast } if @Waiters.clear
          call_callbacks
        else
          Concurrent::MultipleAssignmentError.new('multiple assignment') if raise
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

      private

      def wait_until_complete(timeout)
        lock = Synchronization::Lock.new

        while true
          last_waiter = @Waiters.peek # waiters' state before completion
          break if completed?

          # synchronize so it cannot be signaled before it waits
          synchronize do
            # ok only if completing thread did not start signaling
            next unless @Waiters.compare_and_push last_waiter, lock
            ns_wait_until(timeout) { completed? }
            break
          end
        end
        self
      end

      def complete_state
        @State.compare_and_set :pending, :completed
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

    class Future < Event
      Success = ImmutableStruct.new :value do
        def reason
          nil
        end

        def to_s
          'success'
        end
      end

      Failed = ImmutableStruct.new :reason do
        def value
          nil
        end

        def to_s
          'failed'
        end
      end

      # Has the Future been success?
      # @return [Boolean]
      def success?(state = self.state)
        Success === state
      end

      # Has the Future been failed?
      # @return [Boolean]
      def failed?(state = self.state)
        Failed === state
      end

      # Has the Future been completed?
      # @return [Boolean]
      def completed?(state = self.state)
        success? state or failed? state
      end

      # @return [Object] see Dereferenceable#deref
      def value(timeout = nil)
        touch
        wait_until_complete timeout
        state.value
      end

      def reason(timeout = nil)
        touch
        wait_until_complete timeout
        state.reason
      end

      def result(timeout = nil)
        touch
        wait_until_complete timeout
        state = self.state
        [success?(state), state.value, state.reason]
      end

      # wait until Obligation is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @return [Event] self
      # @raise [Exception] when #failed? it raises #reason
      def wait!(timeout = nil)
        touch
        wait_until_complete! timeout
      end

      # @raise [Exception] when #failed? it raises #reason
      # @return [Object] see Dereferenceable#deref
      def value!(timeout = nil)
        touch
        wait_until_complete!(timeout)
        state.value
      end

      # @example allows failed Future to be risen
      #   raise Concurrent.future.fail
      def exception(*args)
        touch
        raise 'obligation is not failed' unless failed?
        state.reason.exception(*args)
      end

      # @yield [value] executed only on parent success
      def then(executor = nil, &callback)
        ThenPromise.new(self, @DefaultExecutor, executor || @DefaultExecutor, &callback).future
      end

      # Creates new future where its value is result of asking actor with value of this Future.
      def then_ask(actor)
        self.then { |v| actor.ask(v) }.flat
      end

      # @yield [reason] executed only on parent failure
      def rescue(executor = nil, &callback)
        RescuePromise.new(self, @DefaultExecutor, executor || @DefaultExecutor, &callback).future
      end

      def flat(level = 1)
        FlattingPromise.new(self, level, @DefaultExecutor).future
      end

      def any(*futures)
        AnyPromise.new([self, *futures], @DefaultExecutor).future
      end

      alias_method :|, :any

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
      def apply_value(value, block)
        block.call value
      end

      # @!visibility private
      def complete(success, value, reason, raise = true)
        if complete_state success, value, reason
          @Waiters.clear
          synchronize { ns_broadcast }
          call_callbacks success, value, reason
        else
          raise reason || Concurrent::MultipleAssignmentError.new('multiple assignment') if raise
          return false
        end
        self
      end

      def add_callback(method, *args)
        state = self.state
        if completed?(state)
          call_callback method, success?(state), state.value, state.reason, *args
        else
          @Callbacks.push [method, *args]
          state = self.state
          # take back if it was completed in the meanwhile
          call_callbacks success?(state), state.value, state.reason if completed?(state)
        end
        self
      end

      private

      def wait_until_complete!(timeout = nil)
        wait_until_complete(timeout)
        raise self if failed?
        self
      end

      def complete_state(success, value, reason)
        @State.compare_and_set :pending, success ? Success.new(value) : Failed.new(reason)
      end

      def call_callbacks(success, value, reason)
        method, *args = @Callbacks.pop
        while method
          call_callback method, success, value, reason, *args
          method, *args = @Callbacks.pop
        end
      end

      def call_callback(method, success, value, reason, *args)
        self.send method, success, value, reason, *args
      end

      def pr_async_callback_on_success(success, value, reason, executor, callback)
        pr_with_async(executor, success, value, reason, callback) do |success, value, reason, callback|
          pr_callback_on_success success, value, reason, callback
        end
      end

      def pr_async_callback_on_failure(success, value, reason, executor, callback)
        pr_with_async(executor, success, value, reason, callback) do |success, value, reason, callback|
          pr_callback_on_failure success, value, reason, callback
        end
      end

      def pr_callback_on_success(success, value, reason, callback)
        apply_value value, callback if success
      end

      def pr_callback_on_failure(success, value, reason, callback)
        callback.call reason unless success
      end

      def pr_callback_on_completion(success, value, reason, callback)
        callback.call success, value, reason
      end

      def pr_callback_notify_blocked(success, value, reason, promise)
        super(promise)
      end

      def pr_async_callback_on_completion(success, value, reason, executor, callback)
        pr_with_async(executor, success, value, reason, callback) do |success, value, reason, callback|
          pr_callback_on_completion success, value, reason, callback
        end
      end
    end

    class CompletableEvent < Event
      # Complete the event
      def complete(raise = true)
        super raise
      end
    end

    class CompletableFuture < Future
      # Complete the future
      def complete(success, value, reason, raise = true)
        super success, value, reason, raise
      end

      def success(value)
        promise.success(value)
      end

      def try_success(value)
        promise.try_success(value)
      end

      def fail(reason = StandardError.new)
        promise.fail(reason)
      end

      def try_fail(reason = StandardError.new)
        promise.try_fail(reason)
      end

      def evaluate_to(*args, &block)
        promise.evaluate_to(*args, block)
      end

      def evaluate_to!(*args, &block)
        promise.evaluate_to!(*args, block)
      end
    end

    # TODO modularize blocked_by and notify blocked

    # @abstract
    class AbstractPromise < Synchronization::Object
      def initialize(future)
        super(&nil)
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

    class CompletableEventPromise < AbstractPromise
      public :complete

      def initialize(default_executor = :io)
        super CompletableEvent.new(self, default_executor)
      end
    end

    # @note Be careful not to fullfill the promise twice
    class CompletableFuturePromise < AbstractPromise
      # TODO consider to allow being blocked_by

      def initialize(default_executor = :io)
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
    class InnerPromise < AbstractPromise
    end

    # @abstract
    class BlockedPromise < InnerPromise
      def initialize(future, blocked_by_futures, countdown, &block)
        initialize_blocked_by(blocked_by_futures)
        @Countdown = AtomicFixnum.new countdown

        super(future)
        blocked_by.each { |future| future.add_callback :pr_callback_notify_blocked, self }
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

      # @api private
      # for inspection only
      def blocked_by
        @BlockedBy
      end

      def inspect
        "#{to_s[0..-2]} blocked_by:[#{ blocked_by.map(&:to_s).join(', ')}]>"
      end

      private

      def initialize_blocked_by(blocked_by_futures)
        (@BlockedBy = Array(blocked_by_futures).freeze).size
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
    class BlockedTaskPromise < BlockedPromise
      def initialize(blocked_by_future, default_executor = :io, executor = default_executor, &task)
        raise ArgumentError, 'no block given' unless block_given?
        @Executor = executor
        @Task     = task
        super Future.new(self, default_executor), blocked_by_future, 1
      end

      def executor
        @Executor
      end
    end

    class ThenPromise < BlockedTaskPromise
      private

      def initialize(blocked_by_future, default_executor = :io, executor = default_executor, &task)
        raise ArgumentError, 'only Future can be appended with then' unless blocked_by_future.is_a? Future
        super blocked_by_future, default_executor, executor, &task
      end

      def on_completable(done_future)
        if done_future.success?
          Concurrent.post_on(@Executor, done_future, @Task) do |done_future, task|
            evaluate_to lambda { done_future.apply_value done_future.value, task }
          end
        else
          complete false, nil, done_future.reason
        end
      end
    end

    class RescuePromise < BlockedTaskPromise
      private

      def initialize(blocked_by_future, default_executor = :io, executor = default_executor, &task)
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
    class ImmediatePromise < InnerPromise
      def initialize(default_executor = :io)
        super Event.new(self, default_executor).complete
      end
    end

    class FlattingPromise < BlockedPromise
      def blocked_by
        @BlockedBy.each.to_a
      end

      private

      def process_on_done(future)
        countdown = super(future)
        value     = future.value
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

      def initialize(blocked_by_future, levels = 1, default_executor = :io)
        raise ArgumentError, 'levels has to be higher than 0' if levels < 1
        blocked_by_future.is_a? Future or
            raise ArgumentError, 'only Future can be flatten'
        super Future.new(self, default_executor), blocked_by_future, 1 + levels
      end

      def initialize_blocked_by(blocked_by_future)
        @BlockedBy = LockFreeStack.new.push(blocked_by_future)
        1
      end

      def on_completable(done_future)
        complete *done_future.result
      end

      def clear_blocked_by!
        @BlockedBy.clear
        nil
      end
    end

    # used internally to support #with_default_executor
    class AllPromise < BlockedPromise

      class ArrayFuture < Future
        def apply_value(value, block)
          block.call(*value)
        end
      end

      private

      def initialize(blocked_by_futures, default_executor = :io)
        klass = Event
        blocked_by_futures.each do |f|
          if f.is_a?(Future)
            if klass == Event
              klass = Future
            elsif klass == Future
              klass = ArrayFuture
              break
            end
          end
        end

        # noinspection RubyArgCount
        super(klass.new(self, default_executor), blocked_by_futures, blocked_by_futures.size)
      end

      def on_completable(done_future)
        all_success = true
        reason      = nil

        values = blocked_by.each_with_object([]) do |future, values|
          next unless future.is_a?(Future)
          success, value, reason = future.result

          unless success
            all_success = false
            reason      = reason
            break
          end
          values << value
        end

        if all_success
          if values.empty?
            complete
          else
            complete(true, values.size == 1 ? values.first : values, nil)
          end
        else
          # TODO what about other reasons?
          complete false, nil, reason
        end
      end
    end

    class AnyPromise < BlockedPromise

      private

      def initialize(blocked_by_futures, default_executor = :io)
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

    class Delay < InnerPromise
      def touch
        complete
      end

      private

      def initialize(default_executor = :io)
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

      def initialize(intended_time, default_executor = :io)
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

        super Event.new(self, default_executor)

        Concurrent.global_timer_set.post(in_seconds) { complete }
      end
    end
  end

  extend Edge::FutureShortcuts
  include Edge::FutureShortcuts
end
