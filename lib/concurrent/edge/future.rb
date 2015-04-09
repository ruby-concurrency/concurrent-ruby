require 'concurrent'

# TODO support Dereferencable ?
# TODO behaviour with Interrupt exceptions is undefined, use Signal.trap to avoid issues

# @note different name just not to collide for now
module Concurrent
  module Edge

    module FutureShortcuts
      # TODO to construct event to be set later to trigger rest of the tree

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation begins immediately.
      # @return [Future]
      # @note TODO allow to pass in variables as Thread.new(args) {|args| _ } does
      def future(default_executor = :fast, &task)
        ImmediatePromise.new(default_executor).future.chain(&task)
      end

      alias_method :async, :future

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation is delays until
      # requested by {Future#wait} method, {Future#value} and {Future#value!} methods are calling {Future#wait} internally.
      # @return [Delay]
      def delay(default_executor = :fast, &task)
        Delay.new(default_executor).future.chain(&task)
      end

      # Constructs {Promise} which helds its {Future} in {Promise#future} method. Intended for completion by user.
      # User is responsible not to complete the Promise twice.
      # @return [Promise] in this case instance of {OuterPromise}
      def promise(default_executor = :fast)
        OuterPromise.new(default_executor)
      end

      # Schedules the block to be executed on executor in given intended_time.
      # @return [Future]
      def schedule(intended_time, default_executor = :fast, &task)
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

      def post(executor = :io, &job)
        Concurrent.executor(executor).post &job
      end

      # TODO add first(futures, count=count)
      # TODO allow to to have a join point for many futures and process them in batches by 10
    end

    extend FutureShortcuts
    include FutureShortcuts

    class Event < Concurrent::SynchronizedObject
      extend FutureShortcuts

      # @api private
      def initialize(promise, default_executor = :fast)
        super()
        synchronize { ns_initialize(promise, default_executor) }
      end

      # Is obligation completion still pending?
      # @return [Boolean]
      def pending?
        synchronize { ns_pending? }
      end

      alias_method :incomplete?, :pending?

      def completed?
        synchronize { ns_completed? }
      end

      # wait until Obligation is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @return [Obligation] self
      def wait(timeout = nil)
        synchronize { ns_wait(timeout) }
      end

      def touch
        synchronize { ns_touch }
      end

      def state
        synchronize { ns_state }
      end

      def default_executor
        synchronize { ns_default_executor }
      end

      # @yield [success, value, reason] of the parent
      def chain(executor = nil, &callback)
        pr_chain(default_executor, executor, &callback)
      end

      # def then(*args, &callback)
      #   raise # FIXME
      #   chain(*args, &callback)
      # end

      def delay
        pr_delay(default_executor)
      end

      def schedule(intended_time)
        pr_schedule(default_executor, intended_time)
      end

      # @yield [success, value, reason] executed async on `executor` when completed
      # @return self
      def on_completion(executor = nil, &callback)
        synchronize { ns_on_completion(ns_default_executor, executor, &callback) }
      end

      # @yield [success, value, reason] executed sync when completed
      # @return self
      def on_completion!(&callback)
        synchronize { ns_on_completion!(&callback) }
      end

      # @return [Array<Promise>]
      def blocks
        pr_blocks(synchronize { @callbacks })
      end

      def to_s
        synchronize { ns_to_s }
      end

      def inspect
        synchronize { "#{ns_to_s[0..-2]} blocks:[#{pr_blocks(@callbacks).map(&:to_s).join(', ')}]>" }
      end

      def join(*futures)
        pr_join(default_executor, *futures)
      end

      alias_method :+, :join
      alias_method :and, :join

      # @api private
      def complete(raise = true)
        callbacks = synchronize { ns_complete(raise) }
        pr_call_callbacks callbacks
        synchronize { callbacks.clear } # TODO move to upper synchronize ?
        self
      end

      # @api private
      # just for inspection
      def callbacks
        synchronize { @callbacks }.clone.freeze
      end

      # @api private
      def add_callback(method, *args)
        synchronize { ns_add_callback(method, *args) }
      end

      # @api private, only for inspection
      def promise
        synchronize { ns_promise }
      end

      def with_default_executor(executor = default_executor)
        AllPromise.new([self], executor).future
      end

      protected

      def ns_initialize(promise, default_executor = :fast)
        @promise          = promise
        @state            = :pending
        @callbacks        = []
        @default_executor = default_executor
        @touched          = false
      end

      def ns_wait(timeout = nil)
        ns_touch
        super timeout if ns_incomplete?
        self
      end

      def ns_state
        @state
      end

      def ns_pending?
        ns_state == :pending
      end

      alias_method :ns_incomplete?, :ns_pending?

      def ns_completed?
        ns_state == :completed
      end

      def ns_touch
        unless @touched
          @touched = true
          ns_promise.touch
        end
      end

      def ns_promise
        @promise
      end

      def ns_default_executor
        @default_executor
      end

      def pr_chain(default_executor, executor = nil, &callback)
        ChainPromise.new(self, default_executor, executor || default_executor, &callback).future
      end

      def pr_delay(default_executor)
        self.pr_join(default_executor, Delay.new(default_executor).future)
      end

      def pr_schedule(default_executor, intended_time)
        self.pr_chain(default_executor) { ScheduledPromise.new(intended_time).future.join(self) }.flat
      end

      def pr_join(default_executor, *futures)
        AllPromise.new([self, *futures], default_executor).future
      end

      def ns_on_completion(default_executor, executor = nil, &callback)
        ns_add_callback :pr_async_callback_on_completion, executor || default_executor, callback
      end

      def ns_on_completion!(&callback)
        ns_add_callback :pr_callback_on_completion, callback
      end

      def pr_blocks(callbacks)
        callbacks.each_with_object([]) do |callback, promises|
          promises.push *callback.select { |v| v.is_a? Promise }
        end
      end

      def ns_to_s
        "<##{self.class}:0x#{'%x' % (object_id << 1)} #{ns_state}>"
      end

      def ns_complete(raise = true)
        ns_check_multiple_assignment raise
        ns_complete_state
        ns_broadcast
        @callbacks
      end

      def ns_add_callback(method, *args)
        if ns_completed?
          pr_call_callback method, *args
        else
          @callbacks << [method, *args]
        end
        self
      end

      private

      def ns_complete_state
        @state = :completed
      end

      def ns_check_multiple_assignment(raise, reason = nil)
        if ns_completed?
          if raise
            raise reason || Concurrent::MultipleAssignmentError.new('multiple assignment')
          else
            return nil
          end
        end
      end

      def pr_with_async(executor, &block)
        Concurrent.executor(executor).post(&block)
      end

      def pr_async_callback_on_completion(executor, callback)
        pr_with_async(executor) { pr_callback_on_completion callback }
      end

      def pr_callback_on_completion(callback)
        callback.call
      end

      def pr_notify_blocked(promise)
        promise.done self
      end

      def pr_call_callback(method, *args)
        # all methods has to be pure
        raise unless method.to_s =~ /^pr_/ # TODO remove check
        self.send method, *args
      end

      def pr_call_callbacks(callbacks)
        callbacks.each { |method, *args| pr_call_callback method, *args }
      end
    end

    class Future < Event

      # Has the obligation been success?
      # @return [Boolean]
      def success?
        synchronize { ns_success? }
      end

      # Has the obligation been failed?
      # @return [Boolean]
      def failed?
        state == :failed
      end

      # @return [Object] see Dereferenceable#deref
      def value(timeout = nil)
        synchronize { ns_value timeout }
      end

      def reason(timeout = nil)
        synchronize { ns_reason timeout }
      end

      # wait until Obligation is #complete?
      # @param [Numeric] timeout the maximum time in second to wait.
      # @return [Obligation] self
      # @raise [Exception] when #failed? it raises #reason
      def wait!(timeout = nil)
        synchronize { ns_wait! timeout }
      end

      # @raise [Exception] when #failed? it raises #reason
      # @return [Object] see Dereferenceable#deref
      def value!(timeout = nil)
        synchronize { ns_value! timeout }
      end

      # @example allows Obligation to be risen
      #   failed_ivar = Ivar.new.fail
      #   raise failed_ivar
      def exception(*args)
        synchronize { ns_exception(*args) }
      end

      # @yield [value] executed only on parent success
      def then(executor = nil, &callback)
        pr_then(default_executor, executor, &callback)
      end

      # @yield [reason] executed only on parent failure
      def rescue(executor = nil, &callback)
        pr_rescue(default_executor, executor, &callback)
      end

      def flat
        FlattingPromise.new(self, default_executor).future
      end

      def or(*futures)
        AnyPromise.new([self, *futures], default_executor).future
      end

      alias_method :|, :or

      # @yield [value] executed async on `executor` when success
      # @return self
      def on_success(executor = nil, &callback)
        synchronize { ns_on_success(ns_default_executor, executor, &callback) }
      end

      # @yield [reason] executed async on `executor` when failed?
      # @return self
      def on_failure(executor = nil, &callback)
        synchronize { ns_on_failure(ns_default_executor, executor, &callback) }
      end

      # @yield [value] executed sync when success
      # @return self
      def on_success!(&callback)
        synchronize { ns_on_success!(&callback) }
      end

      # @yield [reason] executed sync when failed?
      # @return self
      def on_failure!(&callback)
        synchronize { ns_on_failure!(&callback) }
      end

      # @api private
      def complete(success, value, reason, raise = true)
        callbacks = synchronize { ns_complete(success, value, reason, raise) }
        pr_call_callbacks callbacks, success, value, reason
        synchronize { callbacks.clear } # TODO move up ?
        self
      end

      def ns_add_callback(method, *args)
        if ns_completed?
          pr_call_callback method, ns_completed?, ns_value, ns_reason, *args
        else
          @callbacks << [method, *args]
        end
        self
      end

      protected

      def ns_initialize(promise, default_executor = :fast)
        super(promise, default_executor)
        @value  = nil
        @reason = nil
      end

      def ns_success?
        ns_state == :success
      end

      def ns_failed?
        ns_state == :failed
      end

      def ns_completed?
        [:success, :failed].include? ns_state
      end

      def ns_value(timeout = nil)
        ns_wait timeout
        @value
      end

      def ns_reason(timeout = nil)
        ns_wait timeout
        @reason
      end

      def ns_wait!(timeout = nil)
        ns_wait(timeout)
        raise self if ns_failed?
        self
      end

      def ns_value!(timeout = nil)
        ns_wait!(timeout)
        @value
      end

      def ns_exception(*args)
        raise 'obligation is not failed' unless ns_failed?
        ns_reason.exception(*args)
      end

      def pr_then(default_executor, executor = nil, &callback)
        ThenPromise.new(self, default_executor, executor || default_executor, &callback).future
      end

      def pr_rescue(default_executor, executor = nil, &callback)
        RescuePromise.new(self, default_executor, executor || default_executor, &callback).future
      end

      def ns_on_success(default_executor, executor = nil, &callback)
        ns_add_callback :pr_async_callback_on_success, executor || default_executor, callback
      end

      def ns_on_failure(default_executor, executor = nil, &callback)
        ns_add_callback :pr_async_callback_on_failure, executor || default_executor, callback
      end

      def ns_on_success!(&callback)
        ns_add_callback :pr_callback_on_success, callback
      end

      def ns_on_failure!(&callback)
        ns_add_callback :pr_callback_on_failure, callback
      end

      def ns_complete(success, value, reason, raise = true)
        ns_check_multiple_assignment raise, reason
        ns_complete_state(success, value, reason)
        ns_broadcast
        @callbacks
      end

      private

      def ns_complete_state(success, value, reason)
        if success
          @value = value
          @state = :success
        else
          @reason = reason
          @state  = :failed
        end
      end

      def pr_call_callbacks(callbacks, success, value, reason)
        callbacks.each { |method, *args| pr_call_callback method, success, value, reason, *args }
      end

      def pr_async_callback_on_success(success, value, reason, executor, callback)
        pr_with_async(executor) { pr_callback_on_success success, value, reason, callback }
      end

      def pr_async_callback_on_failure(success, value, reason, executor, callback)
        pr_with_async(executor) { pr_callback_on_failure success, value, reason, callback }
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
        pr_with_async(executor) { pr_callback_on_completion success, value, reason, callback }
      end
    end

    # TODO modularize blocked_by and notify blocked

    # @abstract
    class Promise < Concurrent::SynchronizedObject
      # @api private
      def initialize(future)
        super()
        synchronize { ns_initialize(future) }
      end

      def default_executor
        future.default_executor
      end

      def future
        synchronize { ns_future }
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

      protected

      private

      def ns_initialize(future)
        @future  = future
        @touched = false
      end

      def ns_future
        @future
      end

      def complete(*args)
        future.complete(*args)
      end

      # @return [Future]
      def evaluate_to(*args, &block)
        complete true, block.call(*args), nil
      rescue => error
        complete false, nil, error
      end
    end

    # @note Be careful not to fullfill the promise twice
    # @example initialization
    #   Concurrent.promise
    # @note TODO consider to allow being blocked_by
    class OuterPromise < Promise
      def initialize(default_executor = :fast)
        super Future.new(self, default_executor)
      end

      # Set the `IVar` to a value and wake or notify all threads waiting on it.
      #
      # @param [Object] value the value to store in the `IVar`
      # @raise [Concurrent::MultipleAssignmentError] if the `IVar` has already been set or otherwise completed
      # @return [Future]
      def success(value)
        complete(true, value, nil)
      end

      def try_success(value)
        complete(true, value, nil, false)
      end

      # Set the `IVar` to failed due to some error and wake or notify all threads waiting on it.
      #
      # @param [Object] reason for the failure
      # @raise [Concurrent::MultipleAssignmentError] if the `IVar` has already been set or otherwise completed
      # @return [Future]
      def fail(reason = StandardError.new)
        complete(false, nil, reason)
      end

      def try_fail(reason = StandardError.new)
        !!complete(false, nil, reason, false)
      end

      public :evaluate_to

      # @return [Future]
      def evaluate_to!(*args, &block)
        evaluate_to(*args, &block).no_error!
      end

      # @api private
      public :complete
    end

    # @abstract
    class InnerPromise < Promise
    end

    # @abstract
    class BlockedPromise < InnerPromise
      def self.new(*args)
        promise = super(*args)
        promise.blocked_by.each { |f| f.add_callback :pr_notify_blocked, promise }
        promise
      end

      def initialize(future, blocked_by_futures)
        super future
        synchronize do
          @blocked_by = Array(blocked_by_futures)
          @countdown  = Concurrent::AtomicFixnum.new @blocked_by.size
          @touched    = false
        end
      end

      # @api private
      def done(future) # FIXME pass in success/value/reason to avoid locking
        # futures could be deleted from blocked_by one by one here, but that would too expensive,
        # it's done once when all are done to free the reference
        completable if synchronize { @countdown }.decrement.zero?
      end

      def touch
        propagate_touch if synchronize { @touched ? false : (@touched = true) }
      end

      # @api private
      # for inspection only
      def blocked_by
        synchronize { @blocked_by }
      end

      def inspect
        "#{to_s[0..-2]} blocked_by:[#{synchronize { @blocked_by }.map(&:to_s).join(', ')}]>"
      end

      private

      def completable
        raise NotImplementedError
      end

      def propagate_touch
        blocked_by.each(&:touch)
      end

      def complete(*args)
        super *args
        synchronize { @blocked_by.clear }
      end
    end

    # @abstract
    class BlockedTaskPromise < BlockedPromise
      def initialize(blocked_by_future, default_executor = :fast, executor = default_executor, &task)
        raise ArgumentError, 'no block given' unless block_given?
        super Future.new(self, default_executor), [blocked_by_future]
        synchronize do
          @task     = task
          @executor = executor
        end
      end

      def executor
        synchronize { @executor }
      end

    end

    class ThenPromise < BlockedTaskPromise
      def initialize(blocked_by_future, default_executor = :fast, executor = default_executor, &task)
        blocked_by_future.is_a? Future or
            raise ArgumentError, 'only Future can be appended with then'
        super(blocked_by_future, default_executor, executor, &task)
      end

      private

      def completable
        future = blocked_by.first
        if future.success?
          Concurrent.post(executor) { evaluate_to future.value, &synchronize { @task } }
        else
          complete false, nil, future.reason
        end
      end
    end

    class RescuePromise < BlockedTaskPromise
      def initialize(blocked_by_future, default_executor = :fast, executor = default_executor, &task)
        blocked_by_future.is_a? Future or
            raise ArgumentError, 'only Future can be rescued'
        super(blocked_by_future, default_executor, executor, &task)
      end

      private

      def completable
        future = blocked_by.first
        if future.failed?
          Concurrent.post(executor) { evaluate_to future.reason, &synchronize { @task } }
        else
          complete true, future.value, nil
        end
      end
    end

    class ChainPromise < BlockedTaskPromise
      private

      def completable
        future = blocked_by.first
        if Future === future
          Concurrent.post(executor) do
            evaluate_to future.success?, future.value, future.reason, &synchronize { @task }
          end
        else
          Concurrent.post(executor) { evaluate_to &synchronize { @task } }
        end
      end
    end

    # will be immediately completed
    class ImmediatePromise < InnerPromise
      def self.new(*args)
        promise = super(*args)
        Concurrent.post { promise.future.complete }
        promise
      end


      def initialize(default_executor = :fast)
        super Event.new(self, default_executor)
      end
    end

    # @note TODO add support for levels
    class FlattingPromise < BlockedPromise
      def initialize(blocked_by_future, default_executor = :fast)
        blocked_by_future.is_a? Future or
            raise ArgumentError, 'only Future can be flatten'
        super(Future.new(self, default_executor), [blocked_by_future])
      end

      def done(future)
        value = future.value
        case value
        when Future
          synchronize do
            @countdown.increment
            @blocked_by << value
          end
          value.add_callback :pr_notify_blocked, self
        when Event
          raise TypeError, 'cannot flatten to Event'
        else
          # nothing we are done flattening
        end
        super future
      end

      private

      def completable
        future = blocked_by.last
        complete future.success?, future.value, future.reason
      end
    end

    # used internally to support #with_default_executor
    class AllPromise < BlockedPromise
      def initialize(blocked_by_futures, default_executor = :fast)
        klass = blocked_by_futures.any? { |f| f.is_a?(Future) } ? Future : Event
        super(klass.new(self, default_executor), blocked_by_futures)
      end

      private

      def completable
        results = blocked_by.select { |f| f.is_a?(Future) }
        if results.empty?
          complete
        else
          if results.all?(&:success?)
            params = results.map(&:value)
            complete(true, params.size == 1 ? params.first : params, nil)
          else
            # TODO what about other reasons?
            complete false, nil, results.find(&:failed?).reason
          end
        end
      end
    end

    class AnyPromise < BlockedPromise
      def initialize(blocked_by_futures, default_executor = :fast)
        blocked_by_futures.all? { |f| f.is_a? Future } or
            raise ArgumentError, 'accepts only Futures not Events'
        super(Future.new(self, default_executor), blocked_by_futures)
      end

      def done(future)
        completable(future)
      end

      private

      def completable(future)
        complete future.success?, future.value, future.reason, false
      end
    end

    class Delay < InnerPromise
      def initialize(default_executor = :fast)
        super Event.new(self, default_executor)
        synchronize { @touched = false }
      end

      def touch
        complete if synchronize { @touched ? false : (@touched = true) }
      end
    end

    # will be evaluated to task in intended_time
    class ScheduledPromise < InnerPromise
      def initialize(intended_time, default_executor = :fast)
        super Event.new(self, default_executor)
        in_seconds = synchronize do
          @intended_time = intended_time
          now            = Time.now
          schedule_time  = if intended_time.is_a? Time
                             intended_time
                           else
                             now + intended_time
                           end
          [0, schedule_time.to_f - now.to_f].max
        end

        Concurrent.global_timer_set.post(in_seconds) { complete }
      end

      def intended_time
        synchronize { @intended_time }
      end

      def inspect
        "#{to_s[0..-2]} intended_time:[#{synchronize { @intended_time }}>"
      end
    end
  end

  extend Edge::FutureShortcuts
  include Edge::FutureShortcuts
end
