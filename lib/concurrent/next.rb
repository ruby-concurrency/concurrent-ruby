require 'concurrent'

module Concurrent

  # TODO Dereferencable
  # TODO document new global pool setting: no overflow, user has to buffer when there is too many tasks
  module Next


    # executors do not allocate the threads immediately so they can be constants
    # all thread pools are configured to never reject the job
    # TODO optional auto termination
    module Executors

      IMMEDIATE_EXECUTOR = ImmediateExecutor.new

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

    module Shortcuts

      def post(executor = :fast, &job)
        Next.executor(executor).post &job
        self
      end

      # @return [Future]
      def future(executor = :fast, &block)
        Future.execute executor, &block
      end

      # @return [Delay]
      def delay(executor = :fast, &block)
        Delay.new(executor, &block)
      end

      alias_method :async, :future
    end

    extend Shortcuts

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

    engine = defined?(RUBY_ENGINE) && RUBY_ENGINE
    case engine
    when 'jruby'
      class SynchronizedObject < JavaSynchronizedObject
      end
    when 'rbx'
      raise NotImplementedError # TODO
    else
      class SynchronizedObject < RubySynchronizedObject
      end
    end

    module FutureHelpers
      # fails on first error
      # does not block a thread
      # @return [Future]
      def join(*futures)
        countdown = Concurrent::AtomicFixnum.new futures.size
        promise   = Promise.new.add_blocked_by(*futures) # TODO add injectable executor
        futures.each { |future| future.add_callback :join, countdown, promise, *futures }
        promise.future
      end

      # @return [Future]
      def execute(executor = :fast, &block)
        promise = Promise.new(executor)
        Next.executor(executor).post { promise.evaluate_to &block }
        promise.future
      end
    end

    class Future < SynchronizedObject
      extend FutureHelpers

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

      def promise
        synchronize { @promise }
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

      # TODO add #then_delay { ... } and such to be able to chain delayed evaluations

      # @yield [success, value, reason] of the parent
      def chain(executor = default_executor, &callback)
        add_callback :chain_callback, executor, promise = Promise.new(default_executor).add_blocked_by(self), callback
        promise.future
      end

      # @yield [value] executed only on parent success
      def then(executor = default_executor, &callback)
        add_callback :then_callback, executor, promise = Promise.new(default_executor).add_blocked_by(self), callback
        promise.future
      end

      # @yield [reason] executed only on parent failure
      def rescue(executor = default_executor, &callback)
        add_callback :rescue_callback, executor, promise = Promise.new(default_executor).add_blocked_by(self), callback
        promise.future
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
              raise MultipleAssignmentError.new('multiple assignment')
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
        with_async(executor) do
          with_promise(promise) do
            callback_on_completion callback
          end
        end
      end

      def then_callback(executor, promise, callback)
        with_async(executor) do
          with_promise(promise) do
            success? ? callback.call(value) : raise(reason)
          end
        end
      end

      def rescue_callback(executor, promise, callback)
        with_async(executor) do
          with_promise(promise) do
            callback_on_failure callback
          end
        end
      end

      def with_async(executor)
        Next.executor(executor).post { yield }
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

      def call_callback(method, *args)
        self.send method, *args
      end
    end

    class Promise < SynchronizedObject
      # @api private
      def initialize(executor_or_future = :fast)
        super()
        future = if Future === executor_or_future
                   executor_or_future
                 else
                   Future.new(self, executor_or_future)
                 end

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

      def complete(success, value, reason, raise = true)
        future.complete(success, value, reason, raise)
        synchronize { @blocked_by.clear }
      end

      def state
        future.state
      end

      # @return [Future]
      def evaluate_to(&block)
        success block.call
      rescue => error
        fail error
      end

      # @return [Future]
      def evaluate_to!(&block)
        evaluate_to(&block).no_error!
      end

      # @return [Future]
      def connect_to(future)
        add_blocked_by future
        future.add_callback :set_promise_on_completion, self
        self.future
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

      # @api private
      def add_blocked_by(*futures)
        synchronize { @blocked_by += futures }
        self
      end
    end

    class Delay < Future

      def initialize(default_executor = :fast, &block)
        super(Promise.new(self), default_executor)
        raise ArgumentError.new('no block given') unless block_given?
        synchronize do
          @computing = false
          @task      = block
        end
      end

      def wait(timeout = nil)
        touch
        super timeout
      end

      # starts executing the value without blocking
      def touch
        execute, task = synchronize do
          [(@computing = true unless @computing), @task]
        end

        Next.executor(default_executor).post { promise.evaluate_to &task } if execute
        self
      end
    end

  end
end

include Concurrent::Next
include Concurrent::Next::Shortcuts

puts '-- asynchronous task without Future'
q = Queue.new
post { q << 'a' }
p q.pop

puts '-- asynchronous task with Future'
p future = future { 1 + 1 }
p future.value

puts '-- sync and async callbacks on futures'
future = future { 'value' } # executed on FAST_EXECUTOR pool by default
future.on_completion(:io) { p 'async' } # async callback overridden to execute on IO_EXECUTOR pool
future.on_completion! { p 'sync' } # sync callback executed right after completion in the same thread-pool
p future.value
# it should usually print "sync"\n"async"\n"value"

sleep 0.1

puts '-- future chaining'
future0 = future { 1 }.then { |v| v + 2 } # both executed on default FAST_EXECUTOR
future1 = future0.then(:io) { raise 'boo' } # executed on IO_EXECUTOR
future2 = future1.then { |v| v + 1 } # will fail with 'boo' error, executed on default FAST_EXECUTOR
future3 = future1.rescue { |err| err.message } # executed on default FAST_EXECUTOR
future4 = future0.chain { |success, value, reason| success } # executed on default FAST_EXECUTOR
future5 = Promise.new(:io).connect_to(future3)
future6 = future5.then(&:capitalize) # executes on IO_EXECUTOR because default was set to :io on future5
future7 = Future.join(future0, future3)

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
delay = delay { 1 + 1 }
p delay.completed?, delay.value

puts '-- promise like tree'

# if head of the tree is not constructed with #future but with #delay it does not start execute,
# it's triggered later by calling wait or value on any of the depedent futures or the delay itself
tree = (head = delay { 1 }).then { |v| v.succ }.then(&:succ).then(&:succ)

# meaningful to_s and inspect defined for Future and Promise
puts head
# <#Concurrent::Next::Delay:7f89b4bccc68 pending>
p head
# <#Concurrent::Next::Delay:7f89b4bccc68 pending [<#Concurrent::Next::Promise:7f89b4bccb00 pending>]]>
p head.callbacks
# [[:then_callback, :fast, <#Concurrent::Next::Promise:0x7fa54b31d218 pending [<#Concurrent::Next::Delay:0x7fa54b31d380 pending>]>, #<Proc:0x007fa54b31d290>]]
p tree.value

puts '-- bench'
require 'benchmark'

Benchmark.bmbm(20) do |b|

  parents = [RubySynchronizedObject, (JavaSynchronizedObject if defined? JavaSynchronizedObject)].compact
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

  count = 5_000_000

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
# Concurrent::Next::RubySynchronizedObject   8.010000   6.290000  14.300000 ( 12.197402)
# ------------------------------------------------------------------ total: 14.300000sec
#
# user     system      total        real
# Concurrent::Next::RubySynchronizedObject   8.950000   9.320000  18.270000 ( 15.053220)
#
# JRuby
# Rehearsal ----------------------------------------------------------------------------
# Concurrent::Next::RubySynchronizedObject  10.500000   6.440000  16.940000 ( 10.640000)
# Concurrent::Next::JavaSynchronizedObject   8.410000   0.050000   8.460000 (  4.132000)
# ------------------------------------------------------------------ total: 25.400000sec
#
# user     system      total        real
# Concurrent::Next::RubySynchronizedObject   9.090000   6.640000  15.730000 ( 10.690000)
# Concurrent::Next::JavaSynchronizedObject   8.200000   0.030000   8.230000 (  4.141000)
