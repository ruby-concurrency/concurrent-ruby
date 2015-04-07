require 'thread'

require 'concurrent/atomic/event'
require 'concurrent/executor/executor'
require 'concurrent/utility/monotonic_time'

module Concurrent

  # @!macro thread_pool_executor
  # @!macro thread_pool_options
  class RubyThreadPoolExecutor
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
      self.auto_terminate = opts.fetch(:auto_terminate, true)

      @pool                 = [] # all workers
      @ready                = [] # used as a stash (most idle worker is at the start)
      @queue                = [] # used as queue
      # @ready or @queue is empty at all times
      @scheduled_task_count = 0
      @completed_task_count = 0
      @largest_length       = 0

      @gc_interval  = opts.fetch(:gc_interval, @idletime / 2.0).to_i # undocumented
      @next_gc_time = Concurrent.monotonic_time + @gc_interval
    end

    # @!macro executor_module_method_can_overflow_question
    def can_overflow?
      mutex.synchronize { ns_limited_queue? }
    end

    # The number of threads currently in the pool.
    #
    # @return [Integer] the length
    def length
      mutex.synchronize { @pool.length }
    end

    # The number of tasks in the queue awaiting execution.
    #
    # @return [Integer] the queue_length
    def queue_length
      mutex.synchronize { @queue.length }
    end

    # Number of tasks that may be enqueued before reaching `max_queue` and rejecting
    # new tasks. A value of -1 indicates that the queue may grow without bound.
    #
    # @return [Integer] the remaining_capacity
    def remaining_capacity
      mutex.synchronize do
        if ns_limited_queue?
          @max_queue - @queue.length
        else
          -1
        end
      end
    end

    alias_method :current_length, :length # TODO remove?

    # @api private
    def remove_busy_worker(worker)
      mutex.synchronize { ns_remove_busy_worker worker }
    end

    # @api private
    def ready_worker(worker)
      mutex.synchronize { ns_ready_worker worker }
    end

    # @api private
    def worker_not_old_enough(worker)
      mutex.synchronize { ns_worker_not_old_enough worker }
    end

    # @api private
    def worker_died(worker)
      mutex.synchronize { ns_worker_died worker }
    end

    protected

    def ns_limited_queue?
      @max_queue != 0
    end

    def ns_execute(*args, &task)
      if ns_assign_worker(*args, &task) || ns_enqueue(*args, &task)
        @scheduled_task_count += 1
      else
        handle_fallback(*args, &task)
      end

      ns_prune_pool if @next_gc_time < Concurrent.monotonic_time
      # raise unless @ready.empty? || @queue.empty? # assert
    end

    alias_method :execute, :ns_execute

    def ns_shutdown_execution
      if @pool.empty?
        # nothing to do
        stopped_event.set
      end
      if @queue.empty?
        # no more tasks will be accepted, just stop all workers
        @pool.each(&:stop)
      end

      # raise unless @ready.empty? || @queue.empty? # assert
    end

    alias_method :shutdown_execution, :ns_shutdown_execution

    # @api private
    def ns_kill_execution
      ns_shutdown_execution
      unless stopped_event.wait(1)
        @pool.each &:kill
        @pool.clear
        @ready.clear
        # TODO log out unprocessed tasks in queue
      end
    end

    alias_method :kill_execution, :ns_kill_execution

    # tries to assign task to a worker, tries to get one from @ready or to create new one
    # @return [true, false] if task is assigned to a worker
    def ns_assign_worker(*args, &task)
      # keep growing if the pool is not at the minimum yet
      worker = (@ready.pop if @pool.size >= @min_length) || ns_add_busy_worker
      if worker
        worker << [task, args]
        true
      else
        false
      end
    end

    # tries to enqueue task
    # @return [true, false] if enqueued
    def ns_enqueue(*args, &task)
      if !ns_limited_queue? || @queue.size < @max_queue
        @queue << [task, args]
        true
      else
        false
      end
    end

    def ns_worker_died(worker)
      ns_remove_busy_worker worker
      replacement_worker = ns_add_busy_worker
      ns_ready_worker replacement_worker, false if replacement_worker
    end

    # creates new worker which has to receive work to do after it's added
    # @return [nil, Worker] nil of max capacity is reached
    def ns_add_busy_worker
      return if @pool.size >= @max_length

      @pool << (worker = Worker.new(self))
      @largest_length = @pool.length if @pool.length > @largest_length
      worker
    end

    # handle ready worker, giving it new job or assigning back to @ready
    def ns_ready_worker(worker, success = true)
      @completed_task_count += 1 if success
      task_and_args         = @queue.shift
      if task_and_args
        worker << task_and_args
      else
        # stop workers when !running?, do not return them to @ready
        if running?
          @ready.push(worker)
        else
          worker.stop
        end
      end
    end

    # returns back worker to @ready which was not idle for enough time
    def ns_worker_not_old_enough(worker)
      # let's put workers coming from idle_test back to the start (as the oldest worker)
      @ready.unshift(worker)
      true
    end

    # removes a worker which is not in not tracked in @ready
    def ns_remove_busy_worker(worker)
      @pool.delete(worker)
      stopped_event.set if @pool.empty? && !running?
      true
    end

    # try oldest worker if it is idle for enough time, it's returned back at the start
    def ns_prune_pool
      return if @pool.size <= @min_length

      last_used = @ready.shift
      last_used << :idle_test if last_used

      @next_gc_time = Concurrent.monotonic_time + @gc_interval
    end

    class Worker
      include Logging

      def initialize(pool)
        # instance variables accessed only under pool's lock so no need to sync here again
        @queue  = Queue.new
        @pool   = pool
        @thread = create_worker @queue, pool, pool.idletime
      end

      def <<(message)
        @queue << message
      end

      def stop
        @queue << :stop
      end

      def kill
        @thread.kill
      end

      private

      def create_worker(queue, pool, idletime)
        Thread.new(queue, pool, idletime) do |queue, pool, idletime|
          last_message = Concurrent.monotonic_time
          catch(:stop) do
            loop do

              case message = queue.pop
              when :idle_test
                if (Concurrent.monotonic_time - last_message) > idletime
                  pool.remove_busy_worker(self)
                  throw :stop
                else
                  pool.worker_not_old_enough(self)
                end

              when :stop
                pool.remove_busy_worker(self)
                throw :stop

              else
                task, args = message
                run_task pool, task, args
                last_message = Concurrent.monotonic_time

                pool.ready_worker(self)
              end

            end
          end
        end
      end

      def run_task(pool, task, args)
        task.call(*args)
      rescue => ex
        # let it fail
        log DEBUG, ex
      rescue Exception => ex
        log ERROR, ex
        pool.worker_died(self)
        throw :stop
      end
    end

  end
end
