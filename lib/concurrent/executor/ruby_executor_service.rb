require 'concurrent/executor/abstract_executor_service'
require 'concurrent/atomic/event'

module Concurrent

  # @!macro abstract_executor_service_public_api
  # @!visibility private
  class RubyExecutorService < AbstractExecutorService

    def initialize(*args, &block)
      super
      @stop_event    = Event.new
      @stopped_event = Event.new
      ensure_ivar_visibility!
    end

    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      enqueue_job(0, args, task)
    end

    def shutdown
      synchronize do
        break unless running?
        self.ns_auto_terminate = false
        stop_event.set
        ns_shutdown_execution
      end
      true
    end

    def kill
      synchronize do
        break if shutdown?
        self.ns_auto_terminate = false
        stop_event.set
        ns_kill_execution
        stopped_event.set
      end
      true
    end

    def wait_for_termination(timeout = nil)
      stopped_event.wait(timeout)
    end

    private

    attr_reader :stop_event, :stopped_event

    def prioritize(priority, *args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      enqueue_job(priority, args, task)
    end

    def enqueue_job(priority, args, task)
      job = Job.new(priority, args, task)
      # If the executor is shut down, reject this task
      return handle_fallback(job) unless running?
      synchronize do
        ns_execute(job)
        true
      end
    end

    def ns_shutdown_execution
      stopped_event.set
    end

    def ns_running?
      !stop_event.set?
    end

    def ns_shuttingdown?
      !(ns_running? || ns_shutdown?)
    end

    def ns_shutdown?
      stopped_event.set?
    end
  end
end
