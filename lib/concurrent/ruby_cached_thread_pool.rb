require 'thread'

require 'concurrent/event'
require 'concurrent/ruby_cached_thread_pool/worker'

module Concurrent

  # @!macro cached_thread_pool
  class RubyCachedThreadPool

    # The maximum number of threads that may be created in the pool
    # (unless overridden during construction).
    DEFAULT_MAX_POOL_SIZE = 2**15 # 32768

    # The maximum number of seconds a thread in the pool may remain idle before
    # being reclaimed (unless overridden during construction).
    DEFAULT_THREAD_IDLETIME = 60

    # The maximum number of threads that may be created in the pool.
    attr_accessor :max_threads

    # Create a new thread pool.
    #
    # @param [Hash] opts the options defining pool behavior.
    # @option opts [Integer] :max_threads (+DEFAULT_MAX_POOL_SIZE+) maximum number
    #   of threads which may be created in the pool
    # @option opts [Integer] :thread_idletime (+DEFAULT_THREAD_IDLETIME+) maximum
    #   number of seconds a thread may be idle before it is reclaimed
    #
    # @raise [ArgumentError] if +max_threads+ is less than or equal to zero
    # @raise [ArgumentError] if +thread_idletime+ is less than or equal to zero
    def initialize(opts = {})
      @idletime = (opts[:thread_idletime] || opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
      raise ArgumentError.new('idletime must be greater than zero') if @idletime <= 0

      @max_threads = opts[:max_threads] || opts[:max] || DEFAULT_MAX_POOL_SIZE
      raise ArgumentError.new('maximum_number of threads must be greater than zero') if @max_threads <= 0

      @state = :running
      @pool = []
      @terminator = Event.new
      @mutex = Mutex.new

      @busy = []
      @idle = []
    end

    # Is the thread pool running?
    #
    # @return [Boolean] +true+ when running, +false+ when shutting down or shutdown
    def running?
      return @state == :running
    end

    # Is the thread pool shutdown?
    #
    # @return [Boolean] +true+ when shutdown, +false+ when shutting down or running
    def shutdown?
      return @state != :running
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
      raise ArgumentError.new('no block given') if task.nil?
      @mutex.synchronize do
        break false unless @state == :running

        if @idle.empty?
          if @idle.length + @busy.length < @max_threads
            worker = create_worker_thread
          else
            worker = @busy.shift
          end
        else
          worker = @idle.pop
        end

        @busy.push(worker)
        worker.signal(*args, &task)

        prune_stale_workers
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
        if @idle.empty? && @busy.empty?
          @state = :shutdown
          @terminator.set
        else
          @state = :shuttingdown
          @idle.each{|worker| worker.stop }
          @busy.each{|worker| worker.stop }
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
        @idle.each{|worker| worker.kill }
        @busy.each{|worker| worker.kill }
        @terminator.set
      end
    end

    # The number of threads currently in the pool.
    #
    # @return [Integer] the number of threads in a running pool,
    #   zero when the pool is shutdown
    def length
      @mutex.synchronize do
        @state == :running ? @busy.length + @idle.length : 0
      end
    end
    alias_method :size, :length
    alias_method :current_size, :length
    alias_method :current_length, :length

    # @!visibility private
    def on_worker_exit(worker) # :nodoc:
      @mutex.synchronize do
        @idle.delete(worker)
        @busy.delete(worker)
        if @idle.empty? && @busy.empty? && @state != :running
          @state = :shutdown
          @terminator.set
        end
      end
    end

    # @!visibility private
    def on_end_task(worker) # :nodoc:
      @mutex.synchronize do
        break unless @state == :running
        @busy.delete(worker)
        @idle.push(worker)
      end
    end

    protected

    # @!visibility private
    def create_worker_thread # :nodoc:
      wrkr = Worker.new(self)
      Thread.new(wrkr, self) do |worker, parent|
        Thread.current.abort_on_exception = false
        worker.run
        parent.on_worker_exit(worker)
      end
      return wrkr
    end

    # @!visibility private
    def prune_stale_workers # :nodoc:
      @idle.reject! do |worker|
        if worker.idletime > @idletime
          worker.stop
          true
        else
          worker.dead?
        end
      end
    end
  end
end
