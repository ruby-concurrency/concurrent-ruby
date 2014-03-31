require 'thread'

require 'concurrent/event'
require 'concurrent/ruby_thread_pool_worker'

module Concurrent

  RejectedExecutionError = Class.new(StandardError) unless defined? RejectedExecutionError

  # @!macro thread_pool_executor
  class RubyThreadPoolExecutor

    # The maximum number of threads that will be created in the pool
    # (unless overridden during construction).
    DEFAULT_MAX_POOL_SIZE = 2**15 # 32768

    # The minimum number of threads that will be created in the pool
    # (unless overridden during construction).
    DEFAULT_MIN_POOL_SIZE = 0

    DEFAULT_MAX_QUEUE_SIZE = 0

    # The maximum number of seconds a thread in the pool may remain idle before
    # being reclaimed (unless overridden during construction).
    DEFAULT_THREAD_IDLETIMEOUT = 60

    OVERFLOW_POLICIES = [:abort, :discard, :caller_runs]

    # The maximum number of threads that may be created in the pool.
    attr_reader :max_length
    attr_reader :min_length

    attr_reader :largest_length

    attr_reader :scheduled_task_count
    attr_reader :completed_task_count

    attr_reader :idletime

    attr_reader :max_queue

    attr_reader :overflow_policy

    # Create a new thread pool.
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

      @state = :running
      @pool = []
      @terminator = Event.new
      @queue = Queue.new
      @mutex = Mutex.new
      @scheduled_task_count = 0
      @completed_task_count = 0
      @largest_length = 0

      @gc_interval = opts.fetch(:gc_interval, 1).to_i # undocumented
      @last_gc_time = Time.now.to_f - [1.0, (@gc_interval * 2.0)].max
    end

    def length
      @mutex.synchronize do
        @state != :shutdown ? @pool.length : 0
      end
    end
    alias_method :current_length, :length

    def queue_length
      @queue.length
    end

    def remaining_capacity
      @mutex.synchronize { @max_queue == 0 ? -1 : @max_queue - @queue.length }
    end

    # Is the thread pool running?
    #
    # @return [Boolean] +true+ when running, +false+ when shutting down or shutdown
    def running?
      @mutex.synchronize { @state == :running }
    end

    # Is the thread pool shutdown?
    #
    # @return [Boolean] +true+ when shutdown, +false+ when shutting down or running
    def shutdown?
      @mutex.synchronize { @state != :running }
    end

    # Block until thread pool shutdown is complete or until +timeout+ seconds have
    # passed.
    #
    # @note Does not initiate shutdown or termination. Either +shutdown+ or +kill+
    #   must be called before this method (or on another thread).
    #
    # @param [Integer] timeout the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean] +true+ if shutdown complete or false on +timeout+
    def wait_for_termination(timeout)
      return @terminator.wait(timeout.to_i)
    end

    # Submit a task to the thread pool for asynchronous processing.
    #
    # @param [Array] args zero or more arguments to be passed to the task
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] +true+ if the task is queued, +false+ if the thread pool
    #   is not running
    #
    # @raise [ArgumentError] if no task is given
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      @mutex.synchronize do
        break false unless @state == :running
        return handle_overflow(*args, &task) if @max_queue != 0 && @queue.length >= @max_queue
        @scheduled_task_count += 1
        @queue << [args, task]
        if Time.now.to_f - @gc_interval >= @last_gc_time
          prune_pool
          @last_gc_time = Time.now.to_f
        end
        grow_pool
        true
      end
    end

    # Submit a task to the thread pool for asynchronous processing.
    #
    # @param [Proc] task the asynchronous task to perform
    #
    # @return [self] returns itself
    def <<(task)
      self.post(&task)
      return self
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the
    # thread pool is not running.
    def shutdown
      @mutex.synchronize do
        break unless @state == :running
        @queue.clear
        if @pool.empty?
          @state = :shutdown
          @terminator.set
        else
          @state = :shuttingdown
          @pool.length.times{ @queue << :stop }
        end
      end
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks
    # will be accepted. Has no additional effect if the thread pool is
    # not running.
    def kill
      @mutex.synchronize do
        break if @state == :shutdown
        @queue.clear
        @state = :shutdown
        drain_pool
        @terminator.set
      end
    end

    # @!visibility private
    def on_end_task # :nodoc:
      @mutex.synchronize do
        @completed_task_count += 1 #if success
        break unless @state == :running
      end
    end

    # @!visibility private
    def on_worker_exit(worker) # :nodoc:
      @mutex.synchronize do
        @pool.delete(worker)
        if @pool.empty? && @state != :running
          @state = :shutdown
          @terminator.set
        end
      end
    end

    protected

    # @!visibility private
    def handle_overflow(*args) # :nodoc:
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

    # @!visibility private
    def prune_pool # :nodoc:
      @pool.delete_if do |worker|
        worker.dead? ||
          (@idletime == 0 ? false : Time.now.to_f - @idletime > worker.last_activity)
      end
    end

    # @!visibility private
    def grow_pool # :nodoc:
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

    # @!visibility private
    def drain_pool # :nodoc:
      @pool.each {|worker| worker.kill }
      @pool.clear
    end

    # @!visibility private
    def create_worker_thread # :nodoc:
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
