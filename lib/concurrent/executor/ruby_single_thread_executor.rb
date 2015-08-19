require 'thread'
require 'concurrent/priority_blocking_queue'
require 'concurrent/executor/ruby_executor_service'
require 'concurrent/executor/serial_executor_service'
require 'concurrent/synchronization/object'

module Concurrent

  # @!macro single_thread_executor
  # @!macro thread_pool_options
  # @!macro abstract_executor_service_public_api
  # @!visibility private
  class RubySingleThreadExecutor < RubyExecutorService
    include SerialExecutorService

    STOP_JOB = Job.new(-Infinity, :stop, :stop).freeze
    private_constant :STOP_JOB

    # @!macro single_thread_executor_method_initialize
    def initialize(opts = {})
      super
    end

    # @!macro executor_service_method_prioritized_question
    def prioritized?
      @prioritized
    end

    # @!method prioritize(priority, *args, &task)
    #   @!macro executor_service_method_prioritize
    public :prioritize

    private

    def ns_initialize(opts)
      @prioritized = opts.fetch(:prioritize, false)
      @queue = @prioritized ? Concurrent::PriorityBlockingQueue.new(order: :max) : Queue.new
      @thread = nil
      @fallback_policy = opts.fetch(:fallback_policy, :discard)
      raise ArgumentError.new("#{@fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICIES.include?(@fallback_policy)
      self.auto_terminate = opts.fetch(:auto_terminate, true)
    end

    # @!visibility private
    def ns_execute(job)
      supervise
      @queue.push(job)
    end

    # @!visibility private
    def ns_shutdown_execution
      @queue.push(STOP_JOB)
      stopped_event.set unless alive?
    end

    # @!visibility private
    def ns_kill_execution
      @queue.clear
      @thread.kill if alive?
    end

    # @!visibility private
    def alive?
      @thread && @thread.alive?
    end

    # @!visibility private
    def supervise
      @thread = new_worker_thread unless alive?
    end

    # @!visibility private
    def new_worker_thread
      Thread.new do
        Thread.current.abort_on_exception = false
        work
      end
    end

    # @!visibility private
    def work
      loop do
        job = @queue.pop
        break if job == STOP_JOB
        begin
          job.run
        rescue => ex
          # let it fail
          log DEBUG, ex
        end
      end
      stopped_event.set
    end
  end
end
