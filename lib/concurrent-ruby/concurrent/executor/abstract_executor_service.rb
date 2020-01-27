require 'concurrent/errors'
require 'concurrent/executor/executor_service'
require 'concurrent/synchronization'

module Concurrent

  # @!macro abstract_executor_service_public_api
  # @!visibility private
  class AbstractExecutorService < Synchronization::LockableObject
    include ExecutorService

    # The set of possible fallback policies that may be set at thread pool creation.
    FALLBACK_POLICIES = [:abort, :discard, :caller_runs].freeze

    # @!macro executor_service_attr_reader_fallback_policy
    attr_reader :fallback_policy

    attr_reader :name

    attr_accessor :ns_auto_terminate

    # Create a new thread pool.
    def initialize(opts = {}, &block)
      super(&nil)
      synchronize do
        ns_initialize(opts, &block)
        @name = opts.fetch(:name) if opts.key?(:name)
      end
    end

    def to_s
      name ? "#{super[0..-2]} name: #{name}>" : super
    end

    # @!macro executor_service_method_shutdown
    def shutdown
      raise NotImplementedError
    end

    # @!macro executor_service_method_kill
    def kill
      raise NotImplementedError
    end

    # @!macro executor_service_method_wait_for_termination
    def wait_for_termination(timeout = nil)
      raise NotImplementedError
    end

    # @!macro executor_service_method_running_question
    def running?
      synchronize { ns_running? }
    end

    # @!macro executor_service_method_shuttingdown_question
    def shuttingdown?
      synchronize { ns_shuttingdown? }
    end

    # @!macro executor_service_method_shutdown_question
    def shutdown?
      synchronize { ns_shutdown? }
    end

    # @!macro executor_service_method_auto_terminate_question
    def auto_terminate?
      synchronize { ns_auto_terminate? }
    end

    # @!macro executor_service_method_auto_terminate_setter
    def auto_terminate=(value)
      synchronize { self.ns_auto_terminate = value }
    end

    private

    # Handler which executes the `fallback_policy` once the queue size
    # reaches `max_queue`.
    #
    # @param [Array] args the arguments to the task which is being handled.
    #
    # @!visibility private
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

    def ns_execute(*args, &task)
      raise NotImplementedError
    end

    # @!macro executor_service_method_ns_shutdown_execution
    #
    #   Callback method called when an orderly shutdown has completed.
    #   The default behavior is to signal all waiting threads.
    def ns_shutdown_execution
      # do nothing
    end

    # @!macro executor_service_method_ns_kill_execution
    #
    #   Callback method called when the executor has been killed.
    #   The default behavior is to do nothing.
    def ns_kill_execution
      # do nothing
    end

    def ns_auto_terminate?
      !!ns_auto_terminate
    end

  end
end
