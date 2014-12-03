require 'concurrent'

# TODO Dereferencable
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

  class Future < SynchronizedObject
    module Shortcuts

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation begins immediately.
      # @return [Future]
      def future(executor = :fast, &block)
        ConcurrentNext::Immediate.new(executor, &block).future
      end

      alias_method :async, :future

      # Constructs new Future which will be completed after block is evaluated on executor. Evaluation is delays until
      # requested by {Future#wait} method, {Future#value} and {Future#value!} methods are calling {Future#wait} internally.
      # @return [Delay]
      def delay(executor = :fast, &block)
        ConcurrentNext::Delay.new([], executor, executor, &block).future
      end

      # Constructs {Promise} which helds its {Future} in {Promise#future} method. Intended for completion by user.
      # User is responsible not to complete the Promise twice.
      # @return [Promise] in this case instance of {OuterPromise}
      def promise(executor = :fast)
        ConcurrentNext::OuterPromise.new([], executor)
      end

      # Schedules the block to be executed on executor in given intended_time.
      # @return [Future]
      def schedule(intended_time, executor = :fast, &task)
        Scheduled.new(intended_time, [], executor, &task).future
      end

      # fails on first error
      # does not block a thread
      # @return [Future]
      def join(*futures)
        # TODO consider renaming to zip as in scala
        # TODO what about executor configuration
        JoiningPromise.new(futures).future
      end

      # TODO add any(*futures)
    end

    extend Shortcuts

    # @api private
    def initialize(promise, default_executor = :fast)
      super()
      synchronize do
        @promise          = promise
        @value            = nil
        @reason           = nil
        @state            = :pending
        @callbacks        = []
        @default_executor = default_executor
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

    def state
      synchronize { @state }
    end

    def reason
      synchronize { @reason }
    end

    def default_executor
      synchronize { @default_executor }
    end

    # @example allows Obligation to be risen
    #   failed_ivar = Ivar.new.fail
    #   raise failed_ivar
    def exception(*args)
      raise 'obligation is not failed' unless failed?
      reason.exception(*args)
    end

    def with_default_executor(executor = default_executor)
      JoiningPromise.new([self], executor).future
    end

    alias_method :new_connected, :with_default_executor

    # @yield [success, value, reason] of the parent
    def chain(executor = default_executor, &callback)
      ChainPromise.new([self], default_executor, executor, &callback).future
    end

    # @yield [value] executed only on parent success
    def then(executor = default_executor, &callback)
      ThenPromise.new([self], default_executor, executor, &callback).future
    end

    # @yield [reason] executed only on parent failure
    def rescue(executor = default_executor, &callback)
      RescuePromise.new([self], default_executor, executor, &callback).future
    end

    def delay(executor = default_executor, &task)
      Delay.new([self], default_executor, executor, &task).future
    end

    def flat
      FlattingPromise.new([self], default_executor).future
    end

    def schedule(intended_time)
      Scheduled.new(intended_time, [self], default_executor).future
    end

    # @yield [success, value, reason] executed async on `executor` when completed
    # @return self
    def on_completion(executor = default_executor, &callback)
      add_callback :async_callback_on_completion, executor, callback
    end

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

    # @yield [success, value, reason] executed sync when completed
    # @return self
    def on_completion!(&callback)
      add_callback :callback_on_completion, callback
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
      JoiningPromise.new([self, *futures], default_executor).future
    end

    alias_method :+, :join

    # @api private
    def complete(success, value, reason, raise = true) # :nodoc:
      callbacks = synchronize do
        if completed?
          if raise
            raise Concurrent::MultipleAssignmentError.new('multiple assignment')
          else
            return nil
          end
        end
        if success
          @value = value
          @state = :success
        else
          @reason = reason
          @state  = :failed
        end
        notify_all
        @callbacks
      end

      # TODO pass in local vars to avoid syncing
      callbacks.each { |method, *args| call_callback method, *args }
      callbacks.clear

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

    def set_promise_on_completion(promise)
      promise.complete success?, value, reason
    end

    def with_async(executor)
      ConcurrentNext.executor(executor).post { yield }
    end

    def async_callback_on_completion(executor, callback)
      with_async(executor) { callback_on_completion callback }
    end

    def async_callback_on_success(executor, callback)
      with_async(executor) { callback_on_success callback }
    end

    def async_callback_on_failure(executor, callback)
      with_async(executor) { callback_on_failure callback }
    end

    def callback_on_completion(callback)
      callback.call success?, value, reason
    end

    def callback_on_success(callback)
      callback.call value if success?
    end

    def callback_on_failure(callback)
      callback.call reason if failed?
    end

    def notify_blocked(promise)
      promise.done self
    end

    def call_callback(method, *args)
      self.send method, *args
    end
  end

  extend Future::Shortcuts
  include Future::Shortcuts

  # @abstract
  class Promise < SynchronizedObject
    # @api private
    def initialize(blocked_by_futures, default_executor = :fast)
      super()
      future = Future.new(self, default_executor)

      synchronize do
        @future     = future
        @blocked_by = []
        @touched    = false
      end

      add_blocked_by blocked_by_futures
    end

    def default_executor
      future.default_executor
    end

    def future
      synchronize { @future }
    end

    def blocked_by
      synchronize { @blocked_by }
    end

    def state
      future.state
    end

    def touch
      propagate_touch if synchronize { @touched ? false : (@touched = true) }
    end

    def to_s
      "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state}>"
    end

    def inspect
      "#{to_s[0..-2]} blocked_by:[#{synchronize { @blocked_by }.map(&:to_s).join(', ')}]>"
    end

    private

    def add_blocked_by(futures) # TODO move to BlockedPromise
      synchronize { @blocked_by += Array(futures) }
      self
    end

    def complete(success, value, reason, raise = true)
      future.complete(success, value, reason, raise)
      synchronize { @blocked_by.clear }
    end

    # @return [Future]
    def evaluate_to(*args, &block)
      complete true, block.call(*args), nil
    rescue => error
      complete false, nil, error
    end

    # @return [Future]
    def connect_to(future)
      future.add_callback :set_promise_on_completion, self
      self.future
    end

    def propagate_touch
      blocked_by.each(&:touch)
    end
  end

  # @note Be careful not to fullfill the promise twice
  # @example initialization
  #   ConcurrentNext.promise
  class OuterPromise < Promise

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

    # TODO remove
    def connect_to(future)
      add_blocked_by future
      super future
    end

    # @api private
    public :complete
  end

  # @abstract
  class InnerPromise < Promise
    def initialize(blocked_by_futures, default_executor = :fast, executor = default_executor, &task)
      super blocked_by_futures, default_executor
      synchronize do
        @task      = task
        @executor  = executor
        @countdown = Concurrent::AtomicFixnum.new blocked_by_futures.size
      end

      inner_initialization

      blocked_by_futures.each { |f| f.add_callback :notify_blocked, self }
      resolvable if blocked_by_futures.empty?
    end

    def executor
      synchronize { @executor }
    end

    # @api private
    def done(future) # TODO pass in success/value/reason to avoid locking
      # futures could be deleted from blocked_by one by one here, but that would too expensive,
      # it's done once when all are done to free the reference
      resolvable if synchronize { @countdown }.decrement.zero?
    end

    private

    def inner_initialization
    end

    def resolvable
      resolve
    end

    def resolve
      complete_task(*synchronize { [@executor, @task] })
    end

    def complete_task(executor, task)
      if task
        ConcurrentNext.executor(executor).post { completion task }
      else
        completion nil
      end
    end

    def completion(task)
      raise NotImplementedError
    end
  end

  # used internally to support #with_default_executor
  class JoiningPromise < InnerPromise
    private

    def completion(task)
      if blocked_by.all?(&:success?)
        params = blocked_by.map(&:value)
        if task
          evaluate_to *params, &task
        else
          complete(true, params.size == 1 ? params.first : params, nil)
        end
      else
        # TODO what about other reasons?
        complete false, nil, blocked_by.find(&:failed?).reason
      end
    end
  end

  class FlattingPromise < InnerPromise
    def initialize(blocked_by_futures, default_executor = :fast)
      raise ArgumentError, 'requires one blocked_by_future' unless blocked_by_futures.size == 1
      super(blocked_by_futures, default_executor, default_executor, &nil)
    end

    def done(future)
      value = future.value
      if value.is_a? Future
        synchronize { @countdown }.increment
        add_blocked_by value # TODO DRY
        value.add_callback :notify_blocked, self # TODO DRY
      end
      super future
    end

    def completion(task)
      future = blocked_by.last
      complete future.success?, future.value, future.reason
    end
  end

  module RequiredTask
    def initialize(*args, &task)
      raise ArgumentError, 'no block given' unless block_given?
      super(*args, &task)
    end
  end

  module ZeroOrOneBlockingFuture
    def initialize(blocked_by_futures, *args, &task)
      raise ArgumentError, 'only zero or one blocking future' unless (0..1).cover?(blocked_by_futures.size)
      super(blocked_by_futures, *args, &task)
    end
  end

  module BlockingFutureOrTask
    def initialize(blocked_by_futures, *args, &task)
      raise ArgumentError, 'has to have task or blocked by future' if blocked_by_futures.empty? && task.nil?
      super(blocked_by_futures, *args, &task)
    end

    private

    def completion(task)
      future = blocked_by.first
      if task
        if future
          evaluate_to future.success?, future.value, future.reason, &task
        else
          evaluate_to &task
        end
      else
        if future
          complete future.success?, future.value, future.reason
        else
          raise
        end
      end
    end
  end

  class ThenPromise < InnerPromise
    include RequiredTask
    include ZeroOrOneBlockingFuture

    private

    def completion(task)
      future = blocked_by.first
      if future.success?
        evaluate_to future.value, &task
      else
        complete false, nil, future.reason
      end
    end
  end

  class RescuePromise < InnerPromise
    include RequiredTask
    include ZeroOrOneBlockingFuture

    private

    def completion(task)
      future = blocked_by.first
      if future.failed?
        evaluate_to future.reason, &task
      else
        complete true, future.value, nil
      end
    end
  end

  class ChainPromise < InnerPromise
    include RequiredTask
    include ZeroOrOneBlockingFuture

    private

    def completion(task)
      future = blocked_by.first
      evaluate_to future.success?, future.value, future.reason, &task
    end
  end

  # will be immediately evaluated to task
  class Immediate < InnerPromise
    def initialize(default_executor = :fast, executor = default_executor, &task)
      super([], default_executor, executor, &task)
    end

    private

    def completion(task)
      evaluate_to &task
    end
  end

  # will be evaluated to task in intended_time
  class Scheduled < InnerPromise
    include RequiredTask
    include BlockingFutureOrTask

    def initialize(intended_time, blocked_by_futures, default_executor = :fast, executor = default_executor, &task)
      @intended_time = intended_time
      super(blocked_by_futures, default_executor, executor, &task)
      synchronize { @intended_time = intended_time }
    end

    def intended_time
      synchronize { @intended_time }
    end

    private

    def inner_initialization(*args)
      super *args
      synchronize { @intended_time = intended_time }
    end

    def resolvable
      in_seconds = synchronize do
        now           = Time.now
        schedule_time = if @intended_time.is_a? Time
                          @intended_time
                        else
                          now + @intended_time
                        end
        [0, schedule_time.to_f - now.to_f].max
      end

      Concurrent::timer(in_seconds) { resolve }
    end
  end

  class Delay < InnerPromise
    include ZeroOrOneBlockingFuture
    include BlockingFutureOrTask

    def touch
      if synchronize { @touched ? false : (@touched = true) }
        propagate_touch
        resolve
      end
    end

    private

    def inner_initialization
      super
      synchronize { @resolvable = false }
    end

    def resolvable
      synchronize { @resolvable = true }
      resolve
    end

    def resolve
      super if synchronize { @resolvable && @touched }
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
