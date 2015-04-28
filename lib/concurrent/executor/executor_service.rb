require 'concurrent/logging'
require 'concurrent/synchronization'
require 'concurrent/executor/executor'

module Concurrent

  class AbstractExecutorService < Synchronization::Object
    include Executor
    include Logging

    FALLBACK_POLICIES = [:abort, :discard, :caller_runs].freeze

    attr_reader :fallback_policy

    def initialize
      super()
    end

    def running?
      raise NotImplementedError
    end

    def shuttingdown?
      raise NotImplementedError
    end

    def shutdown?
      raise NotImplementedError
    end

    def shutdown
      raise NotImplementedError
    end

    def kill
      raise NotImplementedError
    end

    def wait_for_termination(timeout = nil)
      raise NotImplementedError
    end

    def auto_terminate?
      synchronize { ns_auto_terminate? }
    end

    def auto_terminate=(value)
      synchronize { self.ns_auto_terminate = value }
    end

    protected

    def handle_fallback(*args)
      case fallback_policy
      when :abort
        raise RejectedExecutionError
      when :discard
        false
      when :caller_runs
        begin
          yield(*args)
        rescue => ex
          # let it fail
          log DEBUG, ex
        end
        true
      else
        fail "Unknown fallback policy #{fallback_policy}"
      end
    end

    def execute(*args, &task)
      raise NotImplementedError
    end

    def shutdown_execution
    end

    def kill_execution
      # do nothing
    end

    private

    def ns_auto_terminate?
      !!@auto_terminate
    end

    def ns_auto_terminate=(value)
      case value
      when true
        AtExit.add(self) { terminate_at_exit }
        @auto_terminate = true
      when false
        AtExit.delete(self)
        @auto_terminate = false
      else
        raise ArgumentError
      end
    end

    def terminate_at_exit
      kill # TODO be gentle first
      wait_for_termination(10)
    end
  end

  class RubyExecutorService < AbstractExecutorService

    def initialize
      super()
      @stop_event    = Event.new
      @stopped_event = Event.new
    end

    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      synchronize do
        # If the executor is shut down, reject this task
        return handle_fallback(*args, &task) unless running?
        execute(*args, &task)
        true
      end
    end

    def running?
      !stop_event.set?
    end

    def shuttingdown?
      !(running? || shutdown?)
    end

    def shutdown?
      stopped_event.set?
    end

    def shutdown
      synchronize do
        break unless running?
        self.ns_auto_terminate = false
        stop_event.set
        shutdown_execution
      end
      true
    end

    def kill
      synchronize do
        break if shutdown?
        self.ns_auto_terminate = false
        stop_event.set
        kill_execution
        stopped_event.set
      end
      true
    end

    def wait_for_termination(timeout = nil)
      stopped_event.wait(timeout)
    end

    protected

    attr_reader :stop_event, :stopped_event

    def shutdown_execution
      stopped_event.set
    end
  end

  if Concurrent.on_jruby?

    class JavaExecutorService < AbstractExecutorService
      include Executor
      java_import 'java.lang.Runnable'

      FALLBACK_POLICY_CLASSES = {
        abort:       java.util.concurrent.ThreadPoolExecutor::AbortPolicy,
        discard:     java.util.concurrent.ThreadPoolExecutor::DiscardPolicy,
        caller_runs: java.util.concurrent.ThreadPoolExecutor::CallerRunsPolicy
      }.freeze
      private_constant :FALLBACK_POLICY_CLASSES

      def initialize
        super()
      end

      def post(*args, &task)
        raise ArgumentError.new('no block given') unless block_given?
        return handle_fallback(*args, &task) unless running?
        executor_submit = @executor.java_method(:submit, [Runnable.java_class])
        executor_submit.call { yield(*args) }
        true
      rescue Java::JavaUtilConcurrent::RejectedExecutionException
        raise RejectedExecutionError
      end

      def running?
        !(shuttingdown? || shutdown?)
      end

      def shuttingdown?
        if @executor.respond_to? :isTerminating
          @executor.isTerminating
        else
          false
        end
      end

      def shutdown?
        @executor.isShutdown || @executor.isTerminated
      end

      def wait_for_termination(timeout = nil)
        if timeout.nil?
          ok = @executor.awaitTermination(60, java.util.concurrent.TimeUnit::SECONDS) until ok
          true
        else
          @executor.awaitTermination(1000 * timeout, java.util.concurrent.TimeUnit::MILLISECONDS)
        end
      end

      def shutdown
        self.ns_auto_terminate = false
        @executor.shutdown
        nil
      end

      def kill
        self.ns_auto_terminate = false
        @executor.shutdownNow
        nil
      end
    end
  end
end
