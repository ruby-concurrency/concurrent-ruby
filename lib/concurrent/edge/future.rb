require 'concurrent'

# TODO support Dereferencable ?
# TODO behaviour with Interrupt exceptions is undefined, use Signal.trap to avoid issues

# @note different name just not to collide for now
module Concurrent
  module Edge

    module FutureShortcuts
      # TODO to construct event to be set later to trigger rest of the tree

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
      def join(*futures)
        AllPromise.new(futures).future
      end

      # TODO pick names for join, any on class/instance
      #   consider renaming to zip as in scala
      alias_method :all, :join
      alias_method :zip, :join

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
      # TODO allow to to have a join point for many futures and process them in batches by 10
    end

    extend FutureShortcuts
    include FutureShortcuts

    class Event < Synchronization::Object
      extend FutureShortcuts

      attr_volatile :state
      private :state=

      def initialize(promise, default_executor = :io)
        @Promise         = promise
        @DefaultExecutor = default_executor
        @Touched         = AtomicBoolean.new(false)
        self.state       = :pending
        super()
        ensure_ivar_visibility!
      end

      # Is Future still pending?
      # @return [Boolean]
      def pending?
        state == :pending
      end

      alias_method :incomplete?, :pending?

      # Is Future still completed?
      # @return [Boolean]
      def completed?
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
      def join(*futures)
        AllPromise.new([self, *futures], @DefaultExecutor).future
      end

      def delay
        join(Delay.new(@DefaultExecutor).future)
      end

      def schedule(intended_time)
        chain { ScheduledPromise.new(intended_time).future.join(self) }.flat
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

      # @return [Array<AbstractPromise>]
      def blocks
        pr_blocks(synchronize { @callbacks })
      end

      def to_s
        synchronize { ns_to_s }
      end

      def inspect
        synchronize { "#{ns_to_s[0..-2]} blocks:[#{pr_blocks(@callbacks).map(&:to_s).join(', ')}]>" }
      end

      alias_method :+, :join
      alias_method :and, :join

      # @api private
      def complete(raise = true)
        callbacks = synchronize { ns_complete raise }
        pr_call_callbacks callbacks
        self
      end

      # @api private
      # just for inspection
      def callbacks
        synchronize { @callbacks }.clone.freeze
      end

      # @api private
      def add_callback(method, *args)
        call = if completed?
                 true
               else
                 synchronize do
                   if completed?
                     true
                   else
                     @callbacks << [method, *args]
                     false
                   end
                 end
               end
        pr_call_callback method, *args if call
        self
      end

      # @api private, only for inspection
      def promise
        @Promise
      end

      # @api private, only for inspection
      def touched
        @Touched.value
      end

      def with_default_executor(executor = @DefaultExecutor)
        AllPromise.new([self], executor).future
      end

      private

      def ns_initialize
        @callbacks = []
      end

      def wait_until_complete(timeout)
        unless completed?
          synchronize { ns_wait_until(timeout) { completed? } }
        end
        self
      end

      def pr_blocks(callbacks)
        callbacks.each_with_object([]) do |callback, promises|
          promises.push *callback.select { |v| v.is_a? AbstractPromise }
        end
      end

      def ns_to_s
        "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state}>" # TODO check ns status
      end

      def ns_complete(raise = true)
        ns_check_multiple_assignment raise
        ns_complete_state
        ns_broadcast
        callbacks, @callbacks = @callbacks, []
        callbacks
      end

      def ns_complete_state
        self.state = :completed
      end

      def ns_check_multiple_assignment(raise, reason = nil)
        if completed?
          if raise
            raise reason || Concurrent::MultipleAssignmentError.new('multiple assignment')
          else
            return nil
          end
        end
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

      def pr_notify_blocked(promise)
        promise.on_done self
      end

      def pr_call_callback(method, *args)
        # all methods has to be pure
        self.send method, *args
      end

      def pr_call_callbacks(callbacks)
        callbacks.each { |method, *args| pr_call_callback method, *args }
      end
    end

    class Future < Event

      private *attr_volatile(:value_field, :reason_field)

      def initialize(promise, default_executor = :io)
        self.value_field  = nil
        self.reason_field = nil
        super promise, default_executor
      end

      # Has the Future been success?
      # @return [Boolean]
      def success?
        state == :success
      end

      # Has the Future been failed?
      # @return [Boolean]
      def failed?
        state == :failed
      end

      # Has the Future been completed?
      # @return [Boolean]
      def completed?
        [:success, :failed].include? state
      end

      # @return [Object] see Dereferenceable#deref
      def value(timeout = nil)
        touch
        wait_until_complete timeout
        value_field
      end

      def reason(timeout = nil)
        touch
        wait_until_complete timeout
        reason_field
      end

      def result(timeout = nil)
        touch
        wait_until_complete timeout
        [success?, value_field, reason_field]
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
        value_field
      end

      # @example allows failed Future to be risen
      #   raise Concurrent.future.fail
      def exception(*args)
        touch
        raise 'obligation is not failed' unless failed?
        reason_field.exception(*args)
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

      def or(*futures)
        AnyPromise.new([self, *futures], @DefaultExecutor).future
      end

      alias_method :|, :or

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

      # @api private
      def complete(success, value, reason, raise = true)
        callbacks = synchronize { ns_complete success, value, reason, raise }
        pr_call_callbacks callbacks, success, value, reason
        self
      end

      def add_callback(method, *args)
        call = if completed?
                 true
               else
                 synchronize do
                   if completed?
                     true
                   else
                     @callbacks << [method, *args]
                     false
                   end
                 end
               end
        pr_call_callback method, success?, value_field, reason_field, *args if call
        self
      end

      private

      def wait_until_complete!(timeout = nil)
        wait_until_complete(timeout)
        raise self if failed?
        self
      end

      def ns_complete(success, value, reason, raise)
        ns_check_multiple_assignment raise, reason
        ns_complete_state(success, value, reason)
        ns_broadcast
        callbacks, @callbacks = @callbacks, []
        callbacks
      end

      def ns_complete_state(success, value, reason)
        if success
          self.value_field = value
          self.state       = :success
        else
          self.reason_field = reason
          self.state        = :failed
        end
      end

      def pr_call_callbacks(callbacks, success, value, reason)
        callbacks.each { |method, *args| pr_call_callback method, success, value, reason, *args }
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
        callback.call value if success
      end

      def pr_callback_on_failure(success, value, reason, callback)
        callback.call reason unless success
      end

      def pr_callback_on_completion(success, value, reason, callback)
        callback.call success, value, reason
      end

      def pr_notify_blocked(success, value, reason, promise)
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
      # @api public
      def complete(raise = true)
        super raise
      end
    end

    class CompletableFuture < Future
      # Complete the future
      # @api public
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
        promise.evaluate_to(*args, &block)
      end

      def evaluate_to!(*args, &block)
        promise.evaluate_to!(*args, &block)
      end
    end

    # TODO modularize blocked_by and notify blocked

    # @abstract
    class AbstractPromise < Synchronization::Object
      def initialize(future, *args, &block)
        super(*args, &block)
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
        pr_complete(@Future, *args)
      end

      def pr_complete(future, *args)
        future.complete(*args)
      end

      def evaluate_to(*args, &block)
        pr_evaluate_to(@Future, *args, &block)
      end

      # @return [Future]
      def pr_evaluate_to(future, *args, &block)
        pr_complete future, true, block.call(*args), nil
      rescue => error
        pr_complete future, false, nil, error
      end
    end

    class CompletableEventPromise < AbstractPromise
      public :complete

      def initialize(default_executor = :io)
        super CompletableEvent.new(self, default_executor)
      end
    end

    # @note Be careful not to fullfill the promise twice
    # @example initialization
    #   Concurrent.promise
    # @note TODO consider to allow being blocked_by
    class CompletableFuturePromise < AbstractPromise
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
      def evaluate_to!(*args, &block)
        evaluate_to(*args, &block).wait!
      end
    end

    # @abstract
    class InnerPromise < AbstractPromise
    end

    # @abstract
    class BlockedPromise < InnerPromise
      def self.new(*args)
        promise = super(*args)
        promise.blocked_by.each { |f| f.add_callback :pr_notify_blocked, promise }
        promise
      end

      def initialize(future, blocked_by_futures, *args, &block)
        @BlockedBy = Array(blocked_by_futures)
        @Countdown = AtomicFixnum.new @BlockedBy.size
        super(future, blocked_by_futures, *args, &block)
      end

      # @api private
      def on_done(future)
        # futures could be deleted from blocked_by one by one here, but that would be too expensive,
        # it's done once when all are done to free the reference

        countdown   = process_on_done(future, @Countdown.decrement)
        completable = completable?(countdown)

        if completable
          pr_on_completable(*pr_on_completable_args(future, blocked_by))
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

      def clear_blocked_by!
        # not synchronized because we do not care when this change propagates
        blocked_by = @BlockedBy
        @BlockedBy = []
        blocked_by
      end

      def inspect
        "#{to_s[0..-2]} blocked_by:[#{ blocked_by.map(&:to_s).join(', ')}]>"
      end

      private

      # @return [true,false] if completable
      def completable?(countdown)
        countdown.zero?
      end

      def process_on_done(future, countdown)
        countdown
      end

      def pr_on_completable_args(done_future, blocked_by)
        [done_future, blocked_by, @Future]
      end

      def pr_on_completable(_, _, _)
        raise NotImplementedError
      end
    end

    # @abstract
    class BlockedTaskPromise < BlockedPromise
      def initialize(blocked_by_future, default_executor = :io, executor = default_executor, &task)
        raise ArgumentError, 'no block given' unless block_given?
        @Executor = executor
        @Task     = task
        super Future.new(self, default_executor), blocked_by_future
      end

      def executor
        @Executor
      end

      private

      def ns_initialize(blocked_by_future)
        super [blocked_by_future]
      end

      def pr_on_completable_args(done_future, blocked_by)
        [done_future, blocked_by, @Future, @Executor, @Task]
      end

      def pr_on_completable(_, _, _, _, _)
        raise NotImplementedError
      end
    end

    class ThenPromise < BlockedTaskPromise
      private

      def ns_initialize(blocked_by_future)
        raise ArgumentError, 'only Future can be appended with then' unless blocked_by_future.is_a? Future
        super(blocked_by_future)
      end

      def pr_on_completable(done_future, _, future, executor, task)
        if done_future.success?
          Concurrent.post_on(executor, done_future, task) { |done_future, task| evaluate_to done_future.value, &task }
        else
          pr_complete future, false, nil, done_future.reason
        end
      end
    end

    class RescuePromise < BlockedTaskPromise
      private

      def ns_initialize(blocked_by_future)
        raise ArgumentError, 'only Future can be rescued' unless blocked_by_future.is_a? Future
        super(blocked_by_future)
      end

      def pr_on_completable(done_future, _, future, executor, task)
        if done_future.failed?
          Concurrent.post_on(executor, done_future, task) { |done_future, task| evaluate_to done_future.reason, &task }
        else
          pr_complete future, true, done_future.value, nil
        end
      end
    end

    class ChainPromise < BlockedTaskPromise
      private

      def pr_on_completable(done_future, _, _, executor, task)
        if Future === done_future
          Concurrent.post_on(executor, done_future, task) { |future, task| evaluate_to *future.result, &task }
        else
          Concurrent.post_on(executor, task) { |task| evaluate_to &task }
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
        synchronize { ns_blocked_by }
      end

      private

      def process_on_done(future, countdown)
        value = future.value
        if @Levels.value > 0
          case value
          when Future
            @Countdown.increment
            @Levels.decrement
            synchronize { @blocked_by << value }
            value.add_callback :pr_notify_blocked, self
            countdown + 1
          when Event
            raise TypeError, 'cannot flatten to Event'
          else
            raise TypeError, "returned value '#{value}' is not a Future"
          end
        else
          countdown
        end
      end

      def initialize(blocked_by_future, levels = 1, default_executor = :io)
        raise ArgumentError, 'levels has to be higher than 0' if levels < 1
        @Levels = AtomicFixnum.new levels
        super Future.new(self, default_executor), blocked_by_future
        @BlockedBy = nil # its not used in FlattingPromise
      end

      def ns_initialize(blocked_by_future)
        blocked_by_future.is_a? Future or
            raise ArgumentError, 'only Future can be flatten'
        @blocked_by = Array(blocked_by_future)
      end

      def pr_on_completable(_, blocked_by, future)
        pr_complete future, *blocked_by.last.result
      end

      def ns_blocked_by
        @blocked_by
      end

      def clear_blocked_by!
        # not synchronized because we do not care when this change propagates
        blocked_by  = @blocked_by
        @blocked_by = []
        blocked_by
      end
    end

    # used internally to support #with_default_executor
    class AllPromise < BlockedPromise
      private

      def initialize(blocked_by_futures, default_executor = :io)
        klass = blocked_by_futures.any? { |f| f.is_a?(Future) } ? Future : Event
        # noinspection RubyArgCount
        super(klass.new(self, default_executor), blocked_by_futures)
      end

      def pr_on_completable(done_future, blocked_by, future)
        results = blocked_by.select { |f| f.is_a?(Future) }.map(&:result)
        if results.empty?
          pr_complete future
        else
          if results.all? { |success, _, _| success }
            params = results.map { |_, value, _| value }
            pr_complete(future, true, params.size == 1 ? params.first : params, nil)
          else
            # TODO what about other reasons?
            pr_complete future.false, nil, results.find { |success, _, _| !success }.last
          end
        end
      end
    end

    class AnyPromise < BlockedPromise

      private

      def initialize(blocked_by_futures, default_executor = :io)
        blocked_by_futures.all? { |f| f.is_a? Future } or
            raise ArgumentError, 'accepts only Futures not Events'
        super(Future.new(self, default_executor), blocked_by_futures)
      end

      def completable?(countdown)
        true
      end

      def pr_on_completable(done_future, _, future)
        pr_complete future, *done_future.result, false
      end
    end

    class Delay < InnerPromise
      def touch
        pr_complete @Future
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
        super Event.new(self, default_executor)
      end

      def ns_initialize
        in_seconds = begin
          now           = Time.now
          schedule_time = if @IntendedTime.is_a? Time
                            @IntendedTime
                          else
                            now + @IntendedTime
                          end
          [0, schedule_time.to_f - now.to_f].max
        end

        Concurrent.global_timer_set.post(in_seconds) { complete }
      end
    end
  end

  extend Edge::FutureShortcuts
  include Edge::FutureShortcuts
end
