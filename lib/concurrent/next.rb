require 'concurrent'

# TODO support Dereferencable ?
# TODO document new global pool setting: no overflow, user has to buffer when there is too many tasks
# TODO behaviour with Interrupt exceptions is undefined, use Signal.trap to avoid issues

# @note different name just not to collide for now
module ConcurrentNext

  # executors do not allocate the threads immediately so they can be constants
  # all thread pools are configured to never reject the job
  # TODO optional auto termination
  module Executors

    IMMEDIATE_EXECUTOR = Concurrent::ImmediateExecutor.new

    # Only non-blocking and short tasks can go into this pool, otherwise it can starve or deadlock
    FAST_EXECUTOR      = Concurrent::FixedThreadPool.new(
        [2, Concurrent.processor_count].max,
        idletime:  60, # 1 minute same as Java pool default
        max_queue: 0 # unlimited
    )

    # IO and blocking jobs should be executed on this pool
    IO_EXECUTOR        = Concurrent::ThreadPoolExecutor.new(
        min_threads: [2, Concurrent.processor_count].max,
        max_threads: Concurrent.processor_count * 100,
        idletime:    60, # 1 minute same as Java pool default
        max_queue:   0 # unlimited
    )

    def executor(which)
      case which
      when :immediate, :immediately
        IMMEDIATE_EXECUTOR
      when :fast
        FAST_EXECUTOR
      when :io
        IO_EXECUTOR
      when Executor
        which
      else
        raise TypeError
      end
    end

    module Shortcuts
      def post(executor = :fast, &job)
        ConcurrentNext.executor(executor).post &job
      end
    end
  end

  extend Executors
  extend Executors::Shortcuts
  include Executors::Shortcuts

  begin
    require 'jruby'

    # roughly more than 2x faster
    class JavaSynchronizedObject
      def initialize
      end

      def synchronize
        JRuby.reference0(self).synchronized { yield }
      end

      def wait(timeout)
        if timeout
          JRuby.reference0(self).wait(timeout * 1000)
        else
          JRuby.reference0(self).wait
        end
      end

      def notify_all
        JRuby.reference0(self).notifyAll
      end
    end
  rescue LoadError
    # ignore
  end

  class RubySynchronizedObject
    def initialize
      @mutex     = Mutex.new
      @condition = Concurrent::Condition.new
    end

    def synchronize
      if @mutex.owned?
        yield
      else
        @mutex.synchronize { yield }
        # rescue ThreadError
        #   yield
      end
    end

    def wait(timeout)
      synchronize { @condition.wait @mutex, timeout }
    end

    def notify
      @condition.signal
    end

    def notify_all
      @condition.broadcast
    end
  end

  case defined?(RUBY_ENGINE) && RUBY_ENGINE
  when 'jruby'
    # @abstract
    class SynchronizedObject < JavaSynchronizedObject
    end
  when 'rbx'
    raise NotImplementedError # TODO
  else
    # @abstract
    class SynchronizedObject < RubySynchronizedObject
    end
  end

  # FIXME turn callbacks into objects

  class Event < SynchronizedObject
    # @api private
    def initialize(promise, default_executor = :fast)
      super()
      synchronize do
        @promise          = promise
        @state            = :pending
        @callbacks        = []
        @default_executor = default_executor
      end
    end

    # Is obligation completion still pending?
    # @return [Boolean]
    def pending?
      state == :pending
    end

    alias_method :incomplete?, :pending?

    def completed?
      state == :completed
    end

    # wait until Obligation is #complete?
    # @param [Numeric] timeout the maximum time in second to wait.
    # @return [Obligation] self
    def wait(timeout = nil)
      synchronize do
        touch
        super timeout if incomplete?
        self
      end
    end

    def touch
      promise.touch
    end

    def state
      synchronize { @state }
    end

    def default_executor
      synchronize { @default_executor }
    end

    # @yield [success, value, reason] of the parent
    def chain(executor = default_executor, &callback)
      ChainPromise.new(self, default_executor, executor, &callback).future
    end

    def then(*args, &callback)
      raise
      chain(*args, &callback)
    end

    def delay
      self.join(Delay.new(default_executor).future)
    end

    def schedule(intended_time)
      self.chain { Scheduled.new(intended_time).future.join(self) }.flat
    end

    # @yield [success, value, reason] executed async on `executor` when completed
    # @return self
    def on_completion(executor = default_executor, &callback)
      add_callback :async_callback_on_completion, executor, callback
    end

    # @yield [success, value, reason] executed sync when completed
    # @return self
    def on_completion!(&callback)
      add_callback :callback_on_completion, callback
    end

    # @return [Array<Promise>]
    def blocks
      synchronize { @callbacks }.each_with_object([]) do |callback, promises|
        promises.push *callback.select { |v| v.is_a? Promise }
      end
    end

    def to_s
      "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state}>"
    end

    def inspect
      "#{to_s[0..-2]} blocks:[#{blocks.map(&:to_s).join(', ')}]>"
    end

    def join(*futures)
      AllPromise.new([self, *futures], default_executor).future
    end

    alias_method :+, :join
    alias_method :and, :join

    # @api private
    def complete(raise = true)
      callbacks = synchronize do
        check_multiple_assignment raise
        complete_state
        notify_all
        @callbacks
      end

      call_callbacks callbacks

      self
    end

    # @api private
    # just for inspection
    def callbacks
      synchronize { @callbacks }.clone.freeze
    end

    # @api private
    def add_callback(method, *args)
      synchronize do
        if completed?
          call_callback method, *args
        else
          @callbacks << [method, *args]
        end
      end
      self
    end

    # @api private, only for inspection
    def promise
      synchronize { @promise }
    end

    private

    def complete_state
      @state = :completed
    end

    def check_multiple_assignment(raise)
      if completed?
        if raise
          raise Concurrent::MultipleAssignmentError.new('multiple assignment')
        else
          return nil
        end
      end
    end

    def with_async(executor)
      ConcurrentNext.executor(executor).post { yield }
    end

    def async_callback_on_completion(executor, callback)
      with_async(executor) { callback_on_completion callback }
    end

    def callback_on_completion(callback)
      callback.call
    end

    def notify_blocked(promise)
      promise.done self
    end

    def call_callback(method, *args)
      self.send method, *args
    end

    def call_callbacks(callbacks)
      # FIXME pass in local vars to avoid syncing
      callbacks.each { |method, *args| call_callback method, *args }
      synchronize { callbacks.clear }
    end
  end

  class Future < Event
    module Shortcuts

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation begins immediately.
      # @return [Future]
      def future(default_executor = :fast, &task)
        ConcurrentNext::Immediate.new(default_executor).future.chain(&task)
      end

      alias_method :async, :future

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation is delays until
      # requested by {Future#wait} method, {Future#value} and {Future#value!} methods are calling {Future#wait} internally.
      # @return [Delay]
      def delay(default_executor = :fast, &task)
        ConcurrentNext::Delay.new(default_executor).future.chain(&task)
      end

      # Constructs {Promise} which helds its {Future} in {Promise#future} method. Intended for completion by user.
      # User is responsible not to complete the Promise twice.
      # @return [Promise] in this case instance of {OuterPromise}
      def promise(default_executor = :fast)
        ConcurrentNext::OuterPromise.new(default_executor)
      end

      # Schedules the block to be executed on executor in given intended_time.
      # @return [Future]
      def schedule(intended_time, default_executor = :fast, &task)
        Scheduled.new(intended_time, default_executor).future.chain(&task)
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
    end

    extend Shortcuts

    # @api private
    def initialize(promise, default_executor = :fast)
      super(promise, default_executor)
      synchronize do
        @value  = nil
        @reason = nil
      end
    end

    # Has the obligation been success?
    # @return [Boolean]
    def success?
      state == :success
    end

    # Has the obligation been failed?
    # @return [Boolean]
    def failed?
      state == :failed
    end

    # Is obligation completion still pending?
    # @return [Boolean]
    def pending?
      state == :pending
    end

    alias_method :incomplete?, :pending?

    def completed?
      [:success, :failed].include? state
    end

    # @return [Object] see Dereferenceable#deref
    def value(timeout = nil)
      wait timeout
      synchronize { @value }
    end

    def reason(timeout = nil)
      wait timeout
      synchronize { @reason }
    end

    # wait until Obligation is #complete?
    # @param [Numeric] timeout the maximum time in second to wait.
    # @return [Obligation] self
    def wait(timeout = nil)
      synchronize do
        touch
        super timeout if incomplete?
        self
      end
    end

    def touch
      promise.touch
    end

    # wait until Obligation is #complete?
    # @param [Numeric] timeout the maximum time in second to wait.
    # @return [Obligation] self
    # @raise [Exception] when #failed? it raises #reason
    def no_error!(timeout = nil)
      wait(timeout).tap { raise self if failed? }
    end

    # @raise [Exception] when #failed? it raises #reason
    # @return [Object] see Dereferenceable#deref
    def value!(timeout = nil)
      val = value(timeout)
      if failed?
        raise self
      else
        val
      end
    end

    # @example allows Obligation to be risen
    #   failed_ivar = Ivar.new.fail
    #   raise failed_ivar
    def exception(*args)
      raise 'obligation is not failed' unless failed?
      reason.exception(*args)
    end

    def with_default_executor(executor = default_executor)
      AllPromise.new([self], executor).future
    end

    # @yield [success, value, reason] of the parent
    def chain(executor = default_executor, &callback)
      ChainPromise.new(self, default_executor, executor, &callback).future
    end

    # @yield [value] executed only on parent success
    def then(executor = default_executor, &callback)
      ThenPromise.new(self, default_executor, executor, &callback).future
    end

    # @yield [reason] executed only on parent failure
    def rescue(executor = default_executor, &callback)
      RescuePromise.new(self, default_executor, executor, &callback).future
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
    def on_success(executor = default_executor, &callback)
      add_callback :async_callback_on_success, executor, callback
    end

    # @yield [reason] executed async on `executor` when failed?
    # @return self
    def on_failure(executor = default_executor, &callback)
      add_callback :async_callback_on_failure, executor, callback
    end

    # @yield [value] executed sync when success
    # @return self
    def on_success!(&callback)
      add_callback :callback_on_success, callback
    end

    # @yield [reason] executed sync when failed?
    # @return self
    def on_failure!(&callback)
      add_callback :callback_on_failure, callback
    end

    # @api private
    def complete(success, value, reason, raise = true)
      callbacks = synchronize do
        check_multiple_assignment raise
        complete_state success, value, reason
        notify_all
        @callbacks
      end

      call_callbacks callbacks

      self
    end

    # @api private
    # just for inspection
    def callbacks
      synchronize { @callbacks }.clone.freeze
    end

    # @api private
    def add_callback(method, *args)
      synchronize do
        if completed?
          call_callback method, *args
        else
          @callbacks << [method, *args]
        end
      end
      self
    end

    # @api private, only for inspection
    def promise
      synchronize { @promise }
    end

    private

    def complete_state(success, value, reason)
      if success
        @value = value
        @state = :success
      else
        @reason = reason
        @state  = :failed
      end
    end

    def async_callback_on_success(executor, callback)
      with_async(executor) { callback_on_success callback }
    end

    def async_callback_on_failure(executor, callback)
      with_async(executor) { callback_on_failure callback }
    end

    def callback_on_success(callback)
      callback.call value if success?
    end

    def callback_on_failure(callback)
      callback.call reason if failed?
    end

    def callback_on_completion(callback)
      callback.call success?, value, reason
    end
  end

  extend Future::Shortcuts
  include Future::Shortcuts

  # TODO modularize blocked_by and notify blocked

  # @abstract
  class Promise < SynchronizedObject
    # @api private
    def initialize(future)
      super()
      synchronize do
        @future  = future
        @touched = false
      end
    end

    def default_executor
      future.default_executor
    end

    def future
      synchronize { @future }
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
  #   ConcurrentNext.promise
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
      promise.blocked_by.each { |f| f.add_callback :notify_blocked, promise }
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
        ConcurrentNext.post(executor) { evaluate_to future.value, &synchronize { @task } }
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
        ConcurrentNext.post(executor) { evaluate_to future.reason, &synchronize { @task } }
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
        ConcurrentNext.post(executor) do
          evaluate_to future.success?, future.value, future.reason, &synchronize { @task }
        end
      else
        ConcurrentNext.post(executor) { evaluate_to &synchronize { @task } }
      end
    end
  end

  # will be immediately completed
  class Immediate < InnerPromise
    def self.new(*args)
      promise = super(*args)
      ConcurrentNext.post { promise.future.complete }
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
        value.add_callback :notify_blocked, self
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
  class Scheduled < InnerPromise
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

      Concurrent::timer(in_seconds) { complete }
    end

    def intended_time
      synchronize { @intended_time }
    end

    def inspect
      "#{to_s[0..-2]} intended_time:[#{synchronize { @intended_time }}>"
    end
  end

end

__END__

puts '-- bench'
require 'benchmark'

count     = 5_000_000
rehersals = 20
count     = 5_000
rehersals = 1

module Benchmark
  def self.bmbmbm(rehearsals, width)
    job = Job.new(width)
    yield(job)
    width       = job.width + 1
    sync        = STDOUT.sync
    STDOUT.sync = true

    # rehearsal
    rehearsals.times do
      puts 'Rehearsal '.ljust(width+CAPTION.length, '-')
      ets = job.list.inject(Tms.new) { |sum, (label, item)|
        print label.ljust(width)
        res = Benchmark.measure(&item)
        print res.format
        sum + res
      }.format("total: %tsec")
      print " #{ets}\n\n".rjust(width+CAPTION.length+2, '-')
    end

    # take
    print ' '*width + CAPTION
    job.list.map { |label, item|
      GC.start
      print label.ljust(width)
      Benchmark.measure(label, &item).tap { |res| print res }
    }
  ensure
    STDOUT.sync = sync unless sync.nil?
  end
end

Benchmark.bmbmbm(rehersals, 20) do |b|

  parents = [ConcurrentNext::RubySynchronizedObject,
             (ConcurrentNext::JavaSynchronizedObject if defined? ConcurrentNext::JavaSynchronizedObject)].compact
  classes = parents.map do |parent|
    klass = Class.new(parent) do
      def initialize
        super
        synchronize do
          @q = []
        end
      end

      def add(v)
        synchronize do
          @q << v
          if @q.size > 100
            @q.clear
          end
        end
      end
    end
    [parent, klass]
  end


  classes.each do |parent, klass|
    b.report(parent) do
      s = klass.new
      2.times.map do
        Thread.new do
          count.times { s.add :a }
        end
      end.each &:join
    end

  end

end

# MRI
# Rehearsal ----------------------------------------------------------------------------
# ConcurrentNext::RubySynchronizedObject   8.010000   6.290000  14.300000 ( 12.197402)
# ------------------------------------------------------------------ total: 14.300000sec
#
#                                              user     system      total        real
# ConcurrentNext::RubySynchronizedObject   8.950000   9.320000  18.270000 ( 15.053220)
#
# JRuby
# Rehearsal ----------------------------------------------------------------------------
# ConcurrentNext::RubySynchronizedObject  10.500000   6.440000  16.940000 ( 10.640000)
# ConcurrentNext::JavaSynchronizedObject   8.410000   0.050000   8.460000 (  4.132000)
# ------------------------------------------------------------------ total: 25.400000sec
#
#                                              user     system      total        real
# ConcurrentNext::RubySynchronizedObject   9.090000   6.640000  15.730000 ( 10.690000)
# ConcurrentNext::JavaSynchronizedObject   8.200000   0.030000   8.230000 (  4.141000)
