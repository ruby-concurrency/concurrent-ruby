require 'concurrent'

# TODO Dereferencable
# TODO document new global pool setting: no overflow, user has to buffer when there is too many tasks

# different name just not to collide
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
  end

  extend Executors

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
      # if @mutex.owned?
      #   yield
      # else
      @mutex.synchronize { yield }
    rescue ThreadError
      yield
      # end
    end

    def wait(timeout)
      @condition.wait @mutex, timeout
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
      def post(executor = :fast, &job)
        ConcurrentNext.executor(executor).post &job
        self
      end

      # @return [Future]
      def future(executor = :fast, &block)
        ConcurrentNext::Immediate.new(executor, &block).future
      end

      alias_method :async, :future

      # @return [Delay]
      def delay(executor = :fast, &block)
        ConcurrentNext::Delay.new(nil, executor, &block).future
      end

      def promise(executor = :fast)
        ConcurrentNext::OuterPromise.new([], executor)
      end

      # fails on first error
      # does not block a thread
      # @return [Future]
      def join(*futures)
        countdown = Concurrent::AtomicFixnum.new futures.size
        promise   = OuterPromise.new(futures)
        futures.each { |future| future.add_callback :join, countdown, promise, *futures }
        promise.future
      end
    end

    extend Shortcuts

    singleton_class.send :alias_method, :dataflow, :join

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
        # TODO interruptions ?
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
      ConnectedPromise.new(self, executor).future
    end

    alias_method :new_connected, :with_default_executor

    # @yield [success, value, reason] of the parent
    def chain(executor = default_executor, &callback)
      add_callback :chain_callback, executor, promise = OuterPromise.new([self], default_executor), callback
      promise.future
    end

    # @yield [value] executed only on parent success
    def then(executor = default_executor, &callback)
      add_callback :then_callback, executor, promise = OuterPromise.new([self], default_executor), callback
      promise.future
    end

    # @yield [reason] executed only on parent failure
    def rescue(executor = default_executor, &callback)
      add_callback :rescue_callback, executor, promise = OuterPromise.new([self], default_executor), callback
      promise.future
    end

    # lazy version of #chain
    def chain_delay(executor = default_executor, &callback)
      delay = Delay.new(self, executor) { callback_on_completion callback }
      delay.future
    end

    # lazy version of #then
    def then_delay(executor = default_executor, &callback)
      delay = Delay.new(self, executor) { conditioned_callback callback }
      delay.future
    end

    # lazy version of #rescue
    def rescue_delay(executor = default_executor, &callback)
      delay = Delay.new(self, executor) { callback_on_failure callback }
      delay.future
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

    def join(countdown, promise, *futures)
      if success?
        promise.success futures.map(&:value) if countdown.decrement.zero?
      else
        promise.try_fail reason
      end
    end

    def with_promise(promise, &block)
      promise.evaluate_to &block
    end

    def chain_callback(executor, promise, callback)
      with_async(executor) { with_promise(promise) { callback_on_completion callback } }
    end

    def then_callback(executor, promise, callback)
      with_async(executor) { with_promise(promise) { conditioned_callback callback } }
    end

    def rescue_callback(executor, promise, callback)
      with_async(executor) { with_promise(promise) { callback_on_failure callback } }
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

    def conditioned_callback(callback)
      self.success? ? callback.call(value) : raise(reason)
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
    def initialize(executor = :fast)
      super()
      future = Future.new(self, executor)

      synchronize do
        @future     = future
        @blocked_by = []
        @touched    = false
      end
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
      blocked_by.each(&:touch) if synchronize { @touched ? false : (@touched = true) }
    end

    def to_s
      "<##{self.class}:0x#{'%x' % (object_id << 1)} #{state}>"
    end

    def inspect
      "#{to_s[0..-2]} blocked_by:[#{synchronize { @blocked_by }.map(&:to_s).join(', ')}]>"
    end

    private

    def add_blocked_by(*futures)
      synchronize { @blocked_by += futures }
      self
    end

    def complete(success, value, reason, raise = true)
      future.complete(success, value, reason, raise)
      synchronize { @blocked_by.clear }
    end

    # @return [Future]
    def evaluate_to(&block)
      complete true, block.call, nil
    rescue => error
      complete false, nil, error
    end

    # @return [Future]
    def connect_to(future)
      add_blocked_by future
      future.add_callback :set_promise_on_completion, self
      self.future
    end
  end

  # @note Be careful not to fullfill the promise twice
  # @example initialization
  #   ConcurrentNext.promise
  class OuterPromise < Promise
    def initialize(blocked_by_futures, executor = :fast)
      super executor
      add_blocked_by *blocked_by_futures
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
    def evaluate_to!(&block)
      evaluate_to(&block).no_error!
    end

    public :connect_to

    # @api private
    public :complete
  end

  # used internally to support #with_default_executor
  class ConnectedPromise < Promise
    def initialize(future, executor = :fast)
      super(executor)
      connect_to future
    end

    # @api private
    public :complete
  end

  # will be immediately evaluated to task
  class Immediate < Promise
    def initialize(executor = :fast, &task)
      super(executor)
      ConcurrentNext.executor(executor).post { evaluate_to &task }
    end
  end

  # will be evaluated to task when first requested
  class Delay < Promise
    def initialize(blocked_by_future, executor = :fast, &task)
      super(executor)
      synchronize do
        @task      = task
        @computing = false
      end
      add_blocked_by blocked_by_future if blocked_by_future
    end

    def touch
      if blocked_by.all?(&:completed?)
        execute_once
      else
        blocked_by.each { |f| f.on_success! { self.touch } unless synchronize { @touched } }
        super
      end
    end

    private

    def execute_once
      execute, task = synchronize do
        [(@computing = true unless @computing), @task]
      end

      if execute
        ConcurrentNext.executor(future.default_executor).post { evaluate_to &task }
      end
      self
    end
  end

end

logger                          = Logger.new($stderr)
logger.level                    = Logger::DEBUG
Concurrent.configuration.logger = lambda do |level, progname, message = nil, &block|
  logger.add level, message, progname, &block
end

puts '-- asynchronous task without Future'
q = Queue.new
ConcurrentNext.post { q << 'a' }
p q.pop

puts '-- asynchronous task with Future'
p future = ConcurrentNext.future { 1 + 1 }
p future.value

puts '-- sync and async callbacks on futures'
future = ConcurrentNext.future { 'value' } # executed on FAST_EXECUTOR pool by default
future.on_completion(:io) { p 'async' } # async callback overridden to execute on IO_EXECUTOR pool
future.on_completion! { p 'sync' } # sync callback executed right after completion in the same thread-pool
p future.value
# it should usually print "sync"\n"async"\n"value"

sleep 0.1

puts '-- future chaining'
future0 = ConcurrentNext.future { 1 }.then { |v| v + 2 } # both executed on default FAST_EXECUTOR
future1 = future0.then(:io) { raise 'boo' } # executed on IO_EXECUTOR
future2 = future1.then { |v| v + 1 } # will fail with 'boo' error, executed on default FAST_EXECUTOR
future3 = future1.rescue { |err| err.message } # executed on default FAST_EXECUTOR
future4 = future0.chain { |success, value, reason| success } # executed on default FAST_EXECUTOR
future5 = future3.with_default_executor(:io) # connects new future with different executor, the new future is completed when future3 is
future6 = future5.then(&:capitalize) # executes on IO_EXECUTOR because default was set to :io on future5
future7 = ConcurrentNext.join(future0, future3)

p future3, future5
p future3.callbacks, future5.callbacks

futures = [future0, future1, future2, future3, future4, future5, future6, future7]
futures.each &:wait


puts 'index success      value reason pool'
futures.each_with_index { |f, i| puts '%5i %7s %10s %6s %4s' % [i, f.success?, f.value, f.reason, f.default_executor] }
# index success      value reason pool
#     0    true          3        fast
#     1   false               boo fast
#     2   false               boo fast
#     3    true        boo        fast
#     4    true       true        fast
#     5    true        boo          io
#     6    true        Boo          io
#     7    true [3, "boo"]        fast

puts '-- delay'

# evaluated on #wait, #value
delay = ConcurrentNext.delay { 1 + 1 }
p delay.completed?, delay.value

puts '-- promise like tree'

# if head of the tree is not constructed with #future but with #delay it does not start execute,
# it's triggered later by calling wait or value on any of the dependent futures or the delay itself
three = (head = ConcurrentNext.delay { 1 }).then { |v| v.succ }.then(&:succ)
four  = three.then_delay(&:succ)

# meaningful to_s and inspect defined for Future and Promise
puts head
# <#ConcurrentNext::Future:0x7fb9dcabacc8 pending>
p head
# <#ConcurrentNext::Future:0x7fb9dcabacc8 pending blocks:[<#ConcurrentNext::ExternalPromise:0x7fb9dcabaac0 pending>]>
p head.callbacks
# [[:then_callback, :fast, <#ConcurrentNext::ExternalPromise:0x7fb9dcabaac0 pending blocked_by:[<#ConcurrentNext::Future:0x7fb9dcabacc8 pending>]>,
#     #<Proc:0x007fb9dcabab38@/Users/pitr/Workspace/redhat/concurrent-ruby/lib/concurrent/next.rb:690>]]


# evaluates only up to three, four is left unevaluated
p three.value # 3
p four, four.promise
# until value is called on four
p four.value # 4

# futures hidden behind two delays trigger evaluation of both
double_delay = ConcurrentNext.delay { 1 }.then_delay(&:succ)
p double_delay.value # 2

puts '-- graph'

head    = ConcurrentNext.future { 1 }
branch1 = head.then(&:succ).then(&:succ)
branch2 = head.then(&:succ).then_delay(&:succ)
result  = ConcurrentNext.join(branch1, branch2).then { |b1, b2| b1 + b2 }

sleep 0.1
p branch1.completed?, branch2.completed? # true, false
# force evaluation of whole graph
p result.value # 6

puts '-- connecting existing promises'

source  = ConcurrentNext.delay { 1 }
promise = ConcurrentNext.promise
promise.connect_to source
p promise.future.value # 1
# or just
p ConcurrentNext.promise.connect_to(source).value

puts '-- using shortcuts'

include ConcurrentNext # includes Future::Shortcuts

# now methods on ConcurrentNext are accessible directly

p delay { 1 }.value, future { 1 }.value # => 1\n1

promise = promise()
promise.connect_to(future { 3 })
p promise.future.value # 3

puts '-- bench'
require 'benchmark'

count     = 5_000_000
count     = 5_000

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
