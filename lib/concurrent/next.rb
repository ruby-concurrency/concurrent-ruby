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

      # @return true
      def post(executor = :fast, &job)
        Next.executor(executor).post &job
      end

      # @return [Future]
      def future(executor = :fast, &block)
        Future.execute executor, &block
      end

      alias_method :async, :future
    end

    extend Shortcuts

    # TODO benchmark java implementation, is it faster as expected?
    class SynchronizedObject

      engine = defined?(RUBY_ENGINE) && RUBY_ENGINE

      case engine
      when 'jruby'
        require 'jruby'

        def initialize
        end

        def synchronize
          JRuby.reference0(self).synchronized { yield }
        end

        def wait(timeout)
          JRuby.reference0(self).wait(timeout ? timeout * 1000 : nil)
        end

        def notify_all
          JRuby.reference0(self).notifyAll
        end

      when 'rbx'

        raise NotImplementedError # TODO

        # def synchronize
        #   Rubinius.lock(self)
        #   yield
        # ensure
        #   Rubinius.unlock(self)
        # end

      else

        def initialize
          @mutex     = Mutex.new
          @condition = Concurrent::Condition.new
        end

        def synchronize
          if @mutex.owned?
            yield
          else
            @mutex.synchronize { yield }
          end
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
    end

    module FutureHelpers
      # fails on first error
      # does not block a thread
      # @return [Future]
      def join(*futures)
        countdown = Concurrent::AtomicFixnum.new futures.size
        promise   = Promise.new # TODO add injectable executor
        futures.each do |future|
          future.on_completion! do |success, _, reason|
            if success
              promise.success futures.map(&:value) if countdown.decrement.zero?
            else
              promise.try_fail reason
            end
          end
        end
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

      def initialize(default_executor = :fast)
        super()
        synchronize do
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
          # TODO interruptions ?
          super timeout if incomplete?
          self
        end
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

      # @yield [success, value, reason] of the parent
      def chain(executor = default_executor, &callback)
        on_completion executor, &with_promise(promise = Promise.new(default_executor), &callback)
        promise.future
      end

      # @yield [value] executed only on parent success
      def then(executor = default_executor, &callback)
        on_completion executor,
                      &with_promise(promise = Promise.new(default_executor),
                                    &-> success, value, reason { success ? callback.call(value) : raise(reason) })
        promise.future
      end

      # @yield [reason] executed only on parent failure
      def rescue(executor = default_executor, &callback)
        on_completion executor,
                      &with_promise(promise = Promise.new(default_executor),
                                    &-> success, value, reason { callback.call(reason) unless success })
        promise.future
      end

      # @yield [success, value, reason] executed async on `executor` when completed
      # @return self
      def on_completion(executor = default_executor, &callback)
        on_completion! &with_async(executor, &callback)
      end

      # @yield [value] executed async on `executor` when success
      # @return self
      def on_success(executor = default_executor, &callback)
        on_success! &with_async(executor, &callback)
      end

      # @yield [reason] executed async on `executor` when failed?
      # @return self
      def on_failure(executor = default_executor, &callback)
        on_failure! &with_async(executor, &callback)
      end

      # @yield [success, value, reason] executed sync when completed
      # @return self
      def on_completion!(&callback)
        add_callback { callback.call success?, value, reason }
      end

      # @yield [value] executed sync when success
      # @return self
      def on_success!(&callback)
        add_callback { callback.call value if success? }
      end

      # @yield [reason] executed sync when failed?
      # @return self
      def on_failure!(&callback)
        add_callback { callback.call reason if failed? }
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

        callbacks.each &:call
        callbacks.clear

        self
      end

      private

      def with_async(executor, &block)
        -> *args { Next.executor(executor).post { block.call *args } }
      end

      def with_promise(promise, &block)
        -> *args { promise.evaluate_to { block.call *args } }
      end

      def add_callback(&callback)
        synchronize do
          if completed?
            callback.call
          else
            @callbacks << callback
          end
        end
        self
      end

    end

    class Promise < SynchronizedObject
      def initialize(executor = :fast)
        super()
        synchronize { @future = Future.new(executor) }
      end

      def future
        synchronize { @future }
      end

      # Set the `IVar` to a value and wake or notify all threads waiting on it.
      #
      # @param [Object] value the value to store in the `IVar`
      # @raise [Concurrent::MultipleAssignmentError] if the `IVar` has already been set or otherwise completed
      # @return [Future]
      def success(value)
        future.complete(true, value, nil)
      end

      def try_success(value)
        future.complete(true, value, nil, false)
      end

      # Set the `IVar` to failed due to some error and wake or notify all threads waiting on it.
      #
      # @param [Object] reason for the failure
      # @raise [Concurrent::MultipleAssignmentError] if the `IVar` has already been set or otherwise completed
      # @return [Future]
      def fail(reason = StandardError.new)
        future.complete(false, nil, reason)
      end

      def try_fail(reason = StandardError.new)
        !!future.complete(false, nil, reason, false)
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
        future.on_completion! { |success, value, reason| self.future.complete success, value, reason }
        self.future
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

futures = [future0, future1, future2, future3, future4, future5, future6, future7].each &:wait


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


