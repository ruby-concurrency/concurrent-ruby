require 'thread'
require 'concurrent'
require 'concurrent/logging'
require 'concurrent/utility/monotonic_time'
require 'concurrent/atomic/event'
require 'concurrent/executor/executor'

module Concurrent

  # @!visibility private
  class RubyThreadPoolWorker
    include Logging

    # @!visibility private
    def initialize(queue, parent)
      @queue         = queue
      @parent        = parent
      @mutex         = Mutex.new
      @last_activity = Concurrent.monotonic_time
      @thread        = nil
    end

    # @!visibility private
    def dead?
      return @mutex.synchronize do
        @thread.nil? ? false : !@thread.alive?
      end
    end

    # @!visibility private
    def last_activity
      @mutex.synchronize { @last_activity }
    end

    def status
      @mutex.synchronize do
        return 'not running' if @thread.nil?
        @thread.status
      end
    end

    # @!visibility private
    def kill
      @mutex.synchronize do
        Thread.kill(@thread) unless @thread.nil?
        @thread = nil
      end
    end

    # @!visibility private
    def run(thread = Thread.current)
      @mutex.synchronize do
        raise StandardError.new('already running') unless @thread.nil?
        @thread = thread
      end

      loop do
        task = @queue.pop
        if task == :stop
          @thread = nil
          @parent.on_worker_exit(self)
          break
        end

        begin
          task.last.call(*task.first)
        rescue => ex
          # let it fail
          log DEBUG, ex
        ensure
          @last_activity = Concurrent.monotonic_time
          @parent.on_end_task
        end
      end
    end
  end

  class OldRubyThreadPoolExecutor
    include RubyExecutor

    # Default maximum number of threads that will be created in the pool.
    DEFAULT_MAX_POOL_SIZE      = 2**15 # 32768

    # Default minimum number of threads that will be retained in the pool.
    DEFAULT_MIN_POOL_SIZE      = 0

    # Default maximum number of tasks that may be added to the task queue.
    DEFAULT_MAX_QUEUE_SIZE     = 0

    # Default maximum number of seconds a thread in the pool may remain idle
    # before being reclaimed.
    DEFAULT_THREAD_IDLETIMEOUT = 60

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
    # accordance with the configured `fallback_policy`.
    attr_reader :max_queue

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
    #   zero means the queue may grow without bound
    # @option opts [Symbol] :fallback_policy (:abort) the policy for handling new
    #   tasks that are received when the queue size has reached
    #   `max_queue` or the executor has shut down
    #
    # @raise [ArgumentError] if `:max_threads` is less than one
    # @raise [ArgumentError] if `:min_threads` is less than zero
    # @raise [ArgumentError] if `:fallback_policy` is not one of the values specified
    #   in `FALLBACK_POLICIES`
    #
    # @see http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
    def initialize(opts = {})
      @min_length      = opts.fetch(:min_threads, DEFAULT_MIN_POOL_SIZE).to_i
      @max_length      = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
      @idletime        = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
      @max_queue       = opts.fetch(:max_queue, DEFAULT_MAX_QUEUE_SIZE).to_i
      @fallback_policy = opts.fetch(:fallback_policy, opts.fetch(:overflow_policy, :abort))
      warn '[DEPRECATED] :overflow_policy is deprecated terminology, please use :fallback_policy instead' if opts.has_key?(:overflow_policy)

      raise ArgumentError.new('max_threads must be greater than zero') if @max_length <= 0
      raise ArgumentError.new('min_threads cannot be less than zero') if @min_length < 0
      raise ArgumentError.new("#{fallback_policy} is not a valid fallback policy") unless FALLBACK_POLICIES.include?(@fallback_policy)
      raise ArgumentError.new('min_threads cannot be more than max_threads') if min_length > max_length

      init_executor
      enable_at_exit_handler!(opts)

      @pool                 = []
      @queue                = Queue.new
      @scheduled_task_count = 0
      @completed_task_count = 0
      @largest_length       = 0

      @gc_interval  = opts.fetch(:gc_interval, 1).to_i # undocumented
      @last_gc_time = Concurrent.monotonic_time - [1.0, (@gc_interval * 2.0)].max
    end

    # @!macro executor_module_method_can_overflow_question
    def can_overflow?
      @max_queue != 0
    end

    # The number of threads currently in the pool.
    #
    # @return [Integer] the length
    def length
      mutex.synchronize { running? ? @pool.length : 0 }
    end

    alias_method :current_length, :length

    # The number of tasks in the queue awaiting execution.
    #
    # @return [Integer] the queue_length
    def queue_length
      mutex.synchronize { running? ? @queue.length : 0 }
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
        if @pool.empty? && !running?
          stop_event.set
          stopped_event.set
        end
      end
    end

    protected

    # @!visibility private
    def execute(*args, &task)
      if ensure_capacity?
        @scheduled_task_count += 1
        @queue << [args, task]
      else
        handle_fallback(*args, &task) if @max_queue != 0 && @queue.length >= @max_queue
      end
      prune_pool
    end

    # @!visibility private
    def shutdown_execution
      if @pool.empty?
        stopped_event.set
      else
        @pool.length.times { @queue << :stop }
      end
    end

    # @!visibility private
    def kill_execution
      @queue.clear
      drain_pool
    end

    # Check the thread pool configuration and determine if the pool
    # has enought capacity to handle the request. Will grow the size
    # of the pool if necessary.
    #
    # @return [Boolean] true if the pool has enough capacity else false
    #
    # @!visibility private
    def ensure_capacity?
      additional = 0
      capacity   = true

      if @pool.size < @min_length
        additional = @min_length - @pool.size
      elsif @queue.empty? && @queue.num_waiting >= 1
        additional = 0
      elsif @pool.size == 0 && @min_length == 0
        additional = 1
      elsif @pool.size < @max_length || @max_length == 0
        additional = 1
      elsif @max_queue == 0 || @queue.size < @max_queue
        additional = 0
      else
        capacity = false
      end

      # puts format('pool %3d queue %3d waiting %3d additional %3d capacity %s', @pool.size, @queue.size, @queue.num_waiting, additional, capacity.to_s)

      additional.times do
        @pool << create_worker_thread
      end

      if additional > 0
        @largest_length = [@largest_length, @pool.length].max
      end

      capacity
    end

    # Scan all threads in the pool and reclaim any that are dead or
    # have been idle too long. Will check the last time the pool was
    # pruned and only run if the configured garbage collection
    # interval has passed.
    #
    # @!visibility private
    def prune_pool
      if Concurrent.monotonic_time - @gc_interval >= @last_gc_time
        @pool.delete_if { |worker| worker.dead? }
        # send :stop for each thread over idletime
        @pool.
            select { |worker| @idletime != 0 && Concurrent.monotonic_time - @idletime > worker.last_activity }.
            each { @queue << :stop }
        @last_gc_time = Concurrent.monotonic_time
      end
    end

    # Reclaim all threads in the pool.
    #
    # @!visibility private
    def drain_pool
      @pool.each { |worker| worker.kill }
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

require 'benchmark/ips'

Benchmark.ips do |x|

  x.time = 10
  x.warmup = if RUBY_ENGINE == 'jruby'
               30
             else
               5
             end

  configuration = { min_threads:     2,
                    max_threads:     8,
                    stop_on_exit:    false,
                    idletime:        60, # 1 minute
                    max_queue:       0, # unlimited
                    fallback_policy: :caller_runs }

  pools = { old: Concurrent::OldRubyThreadPoolExecutor.new(configuration),
            new: Concurrent::RubyThreadPoolExecutor.new(configuration) }
  pools.update java: Concurrent::JavaThreadPoolExecutor.new(configuration) if RUBY_ENGINE == 'jruby'

  pools.each do |name, pool|
    x.report(name.to_s) do
      count = Concurrent::CountDownLatch.new(100)
      100.times do
        pool.post { count.count_down }
      end
      count.wait
    end
  end

  x.compare!
end


