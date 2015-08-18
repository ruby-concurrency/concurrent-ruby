if Concurrent.on_jruby?

  require 'concurrent/errors'
  require 'concurrent/utility/engine'
  require 'concurrent/executor/abstract_executor_service'

  module Concurrent

    # @!macro abstract_executor_service_public_api
    # @!visibility private
    class JavaExecutorService < AbstractExecutorService
      java_import 'java.lang.Runnable'

      FALLBACK_POLICY_CLASSES = {
        abort:       java.util.concurrent.ThreadPoolExecutor::AbortPolicy,
        discard:     java.util.concurrent.ThreadPoolExecutor::DiscardPolicy,
        caller_runs: java.util.concurrent.ThreadPoolExecutor::CallerRunsPolicy
      }.freeze
      private_constant :FALLBACK_POLICY_CLASSES

      class JavaJob
        include java.lang.Runnable
        include java.lang.Comparable

        attr_reader :priority

        def initialize(priority, args, block)
          @priority = priority
          @args = args
          @block = block
        end

        def run
          @block.call(*@args)
        end

        def compareTo(other)
          other.priority <=> @priority
        end
      end
      private_constant :JavaJob

      def initialize(*args, &block)
        super
        ns_make_executor_runnable
      end

      def post(*args, &task)
        raise ArgumentError.new('no block given') unless block_given?
        enqueue_job(0, args, task)
      end

      def prioritize(priority, *args, &task)
        raise ArgumentError.new('no block given') unless block_given?
        enqueue_job(priority, args, task)
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
        synchronize do
          self.ns_auto_terminate = false
          @executor.shutdown
          nil
        end
      end

      def kill
        synchronize do
          self.ns_auto_terminate = false
          @executor.shutdownNow
          nil
        end
      end

      private

      def enqueue_job(priority, args, task)
        job = JavaJob.new(priority, args, task)
        return handle_fallback(job) unless running?
        @executor.execute job
        true
      rescue Java::JavaUtilConcurrent::RejectedExecutionException
        raise RejectedExecutionError
      end

      def ns_running?
        !(ns_shuttingdown? || ns_shutdown?)
      end

      def ns_shuttingdown?
        if @executor.respond_to? :isTerminating
          @executor.isTerminating
        else
          false
        end
      end

      def ns_shutdown?
        @executor.isShutdown || @executor.isTerminated
      end

      def ns_make_executor_runnable
        if !defined?(@executor.submit_runnable)
          @executor.class.class_eval do
            java_alias :submit_runnable, :submit, [java.lang.Runnable.java_class]
          end
        end
      end
    end
  end
end
