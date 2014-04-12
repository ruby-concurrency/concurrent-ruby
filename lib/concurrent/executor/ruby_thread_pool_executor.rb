require 'thread'

require_relative 'executor'
require 'concurrent/atomic/event'
require 'concurrent/executor/ruby_thread_pool_worker'

module Concurrent

  # @!macro thread_pool_executor
  class RubyThreadPoolExecutor
    include Executor

    # Default maximum number of threads that will be created in the pool.
    DEFAULT_MAX_POOL_SIZE = 2**15 # 32768

    # Default minimum number of threads that will be retained in the pool.
    DEFAULT_MIN_POOL_SIZE = 0

    # Default maximum number of tasks that may be added to the task queue.
    DEFAULT_MAX_QUEUE_SIZE = 0

    # Default maximum number of seconds a thread in the pool may remain idle
    # before being reclaimed.
    DEFAULT_THREAD_IDLETIMEOUT = 60

    # The set of possible overflow policies that may be set at thread pool creation.
    OVERFLOW_POLICIES = [:abort, :discard, :caller_runs]

    # The maximum number of threads that may be created in the pool.
    attr_reader :max_length

    # The minimum number of threads that may be retained in the pool.
    attr_reader :min_length

    # The largest number of threads that have been created in the pool since construction.
    attr_reader :largest_length

    # The number of tasks that have been scheduled for execution on the pool since construction.
    attr_reader :scheduled_task_count

    # The number of tasks that have been completed by the pool since construction.
    attr_reader :completed_task_count

    # The number of seconds that a thread may be idle before being reclaimed.
    attr_reader :idletime

    # The maximum number of tasks that may be waiting in the work queue at any one time.
    # When the queue size reaches `max_queue` subsequent tasks will be rejected in
    # accordance with the configured `overflow_policy`.
    attr_reader :max_queue

    # The policy defining how rejected tasks (tasks received once the queue size reaches
    # the configured `max_queue`) are handled. Must be one of the values specified in
    # `OVERFLOW_POLICIES`.
    attr_reader :overflow_policy

    # Create a new thread pool.
    #
    # @param [Hash] opts the options which configure the thread pool
    #
    # @option opts [Integer] :max_threads (DEFAULT_MAX_POOL_SIZE) the maximum
    #   number of threads to be created
    # @option opts [Integer] :min_threads (DEFAULT_MIN_POOL_SIZE) the minimum
    #   number of threads to be retained
    # @option opts [Integer] :idletime (DEFAULT_THREAD_IDLETIMEOUT) the maximum
    #   number of seconds a thread may be idle before being reclaimed
    # @option opts [Integer] :max_queue (DEFAULT_MAX_QUEUE_SIZE) the maximum
    #   number of tasks allowed in the work queue at any one time; a value of
    #   zero means the queue may grow without bounnd
    # @option opts [Symbol] :overflow_policy (:abort) the policy for handling new
    #   tasks that are received when the queue size has reached `max_queue`
    #
    # @raise [ArgumentError] if `:max_threads` is less than one
    # @raise [ArgumentError] if `:min_threads` is less than zero
    # @raise [ArgumentError] if `:overflow_policy` is not one of the values specified
    #   in `OVERFLOW_POLICIES`
    #
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
    def initialize(opts = {})
      @min_length = opts.fetch(:min_threads, DEFAULT_MIN_POOL_SIZE).to_i
      @max_length = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
      @idletime = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
      @max_queue = opts.fetch(:max_queue, DEFAULT_MAX_QUEUE_SIZE).to_i
      @overflow_policy = opts.fetch(:overflow_policy, :abort)

      raise ArgumentError.new('max_threads must be greater than zero') if @max_length <= 0
      raise ArgumentError.new('min_threads cannot be less than zero') if @min_length < 0
      raise ArgumentError.new("#{overflow_policy} is not a valid overflow policy") unless OVERFLOW_POLICIES.include?(@overflow_policy)

      init_executor

      @pool = []
      @queue = Queue.new
      @scheduled_task_count = 0
      @completed_task_count = 0
      @largest_length = 0

      @gc_interval = opts.fetch(:gc_interval, 1).to_i # undocumented
      @last_gc_time = Time.now.to_f - [1.0, (@gc_interval * 2.0)].max
    end

    # The number of threads currently in the pool.
    #
    # @return [Integer] the length
    def length
      mutex.synchronize do
        running? ? @pool.length : 0
      end
    end
    alias_method :current_length, :length

    # The number of tasks in the queue awaiting execution.
    #
    # @return [Integer] the queue_length
    def queue_length
      @queue.length
    end

    # Number of tasks that may be enqueued before reaching `max_queue` and rejecting
    # new tasks. A value of -1 indicates that the queue may grow without bound.
    #
    # @return [Integer] the remaining_capacity
    def remaining_capacity
      mutex.synchronize { @max_queue == 0 ? -1 : @max_queue - @queue.length }
    end

    # Returns an array with the status of each thread in the pool
    #
    # This method is deprecated and will be removed soon.
    def status
      warn '[DEPRECATED] `status` is deprecated and will be removed soon.'
      mutex.synchronize { @pool.collect { |worker| worker.status } }
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
      mutex.synchronize do
        return if shutdown?
        stop_event.set
        @queue.clear
        drain_pool
        stopped_event.set
      end
    end

    # Run on task completion.
    #
    # @!visibility private
    def on_end_task
      mutex.synchronize do
        @completed_task_count += 1 #if success
        break unless running?
      end
    end

    # Run when a thread worker exits.
    #
    # @!visibility private
    def on_worker_exit(worker)
      mutex.synchronize do
        @pool.delete(worker)
        if @pool.empty? && ! running?
          stop_event.set
          stopped_event.set
        end
      end
    end

    protected

    # @!visibility private
    def execute(*args, &task)
      return handle_overflow(*args, &task) if @max_queue != 0 && @queue.length >= @max_queue
      @scheduled_task_count += 1
      @queue << [args, task]
      if Time.now.to_f - @gc_interval >= @last_gc_time
        prune_pool
        @last_gc_time = Time.now.to_f
      end
      grow_pool
    end

    # @!visibility private
    def stop_execution
      @queue.clear
      if @pool.empty?
        stopped_event.set
      else
        @pool.length.times{ @queue << :stop }
      end
    end

    # Handler which executes the `overflow_policy` once the queue size
    # reaches `max_queue`.
    #
    # @param [Array] args the arguments to the task which is being handled.
    #
    # @!visibility private
    def handle_overflow(*args)
      case @overflow_policy
      when :abort
        raise RejectedExecutionError
      when :discard
        false
      when :caller_runs
        begin
          yield(*args)
        rescue
          # let it fail
        end
        true
      end
    end

    # Scan all threads in the pool and reclaim any that are dead or have been idle
    # too long.
    #
    # @!visibility private
    def prune_pool
      @pool.delete_if do |worker|
        worker.dead? ||
          (@idletime == 0 ? false : Time.now.to_f - @idletime > worker.last_activity)
      end
    end

    # Increase the size of the pool when necessary.
    #
    # @!visibility private
    def grow_pool
      if @min_length > @pool.length
        additional = @min_length - @pool.length
      elsif @pool.length < @max_length && ! @queue.empty?
        # NOTE: does not take into account idle threads
        additional = 1
      else
        additional = 0
      end
      additional.times do
        break if @pool.length >= @max_length
        @pool << create_worker_thread
      end
      @largest_length = [@largest_length, @pool.length].max
    end

    # Reclaim all threads in the pool.
    #
    # @!visibility private
    def drain_pool
      @pool.each {|worker| worker.kill }
      @pool.clear
    end

    # Create a single worker thread to be added to the pool.
    #
    # @return [Thread] the new thread.
    #
    # @!visibility private
    def create_worker_thread
      wrkr = RubyThreadPoolWorker.new(@queue, self)
      Thread.new(wrkr, self) do |worker, parent|
        Thread.current.abort_on_exception = false
        worker.run
        parent.on_worker_exit(worker)
      end
      return wrkr
    end
  end
end
