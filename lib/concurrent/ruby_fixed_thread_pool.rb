require 'thread'

require 'concurrent/event'
require 'concurrent/ruby_fixed_thread_pool/worker'

module Concurrent

  # @!macro fixed_thread_pool
  #
  # @note To prevent deadlocks and race conditions, no threads will be allocated
  #   on construction. Threads will be allocated once the first task is post to
  #   the pool. Additionally, threads that crash will be removed from the pool and
  #   replaced. Thus the +#length+ and +#current_length+ may occasionally be
  #   different.
  class RubyFixedThreadPool

    attr_reader :scheduled_task_count
    attr_reader :completed_task_count

    attr_reader :largest_length
    attr_reader :min_length
    attr_reader :max_length

    attr_reader :idletime

    # Create a new thread pool.
    #
    # @param [Integer] num_threads the number of threads to allocate
    #
    # @raise [ArgumentError] if +num_threads+ is less than or equal to zero
    def initialize(num_threads)
      raise ArgumentError.new('number of threads must be greater than zero') if num_threads < 1

      @state = :running
      @pool = []
      @terminator = Event.new
      @queue = Queue.new
      @mutex = Mutex.new
      @scheduled_task_count = 0
      @completed_task_count = 0
      @largest_length = 0
      @min_length = @max_length = num_threads
      @idletime = 0
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
    # @param [Array] args zero or more arguments to be passed to the block
    #
    # @yield the asynchronous task to perform
    #
    # @return [Boolean] +true+ if the task is queued, +false+ if the thread pool
    #   is not running
    #
    # @raise [ArgumentError] if no block is given
    def post(*args, &task)
      raise ArgumentError.new('no block given') unless block_given?
      @mutex.synchronize do
        break false unless @state == :running
        @scheduled_task_count += 1
        @queue << [args, task]
        clean_pool
        fill_pool
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
        @state = :shutdown
        @queue.clear
        drain_pool
        @terminator.set
      end
    end

    # The number of threads currently in the pool.
    #
    # @return [Integer] the number of threads allocated for a running pool,
    #   zero when the pool is shutdown
    def length
      @mutex.synchronize do
        @state != :shutdown ? @pool.length : 0
      end
    end
    alias_method :current_length, :length

    # @!visibility private
    def on_end_task(worker, success) # :nodoc:
      @mutex.synchronize do
        @completed_task_count += 1 #if success
        break unless @state == :running
        clean_pool
        fill_pool
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
    def create_worker_thread # :nodoc:
      wrkr = Worker.new(@queue, self)
      Thread.new(wrkr, self) do |worker, parent|
        Thread.current.abort_on_exception = false
        worker.run
        parent.on_worker_exit(worker)
      end
      return wrkr
    end

    # @!visibility private
    def fill_pool # :nodoc:
      return unless @state == :running
      while @pool.length < @max_length
        @pool << create_worker_thread
      end
      @largest_length = @max_length
    end

    # @!visibility private
    def clean_pool # :nodoc:
      @pool.reject! {|worker| worker.dead? } 
    end

    # @!visibility private
    def drain_pool # :nodoc:
      @pool.each {|worker| worker.kill }
      @pool.clear
    end
  end
end
