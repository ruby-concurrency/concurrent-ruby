require 'thread'

require 'concurrent/event'
require 'concurrent/ruby_cached_thread_pool/worker'

module Concurrent

  class RubyCachedThreadPool

    DEFAULT_POOL_SIZE = 256
    DEFAULT_THREAD_IDLETIME = 60

    attr_accessor :max_threads

    def initialize(opts = {})
      @idletime = (opts[:thread_idletime] || opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
      raise ArgumentError.new('idletime must be greater than zero') if @idletime <= 0

      @max_threads = opts[:max_threads] || opts[:max] || DEFAULT_POOL_SIZE
      raise ArgumentError.new('maximum_number of threads must be greater than zero') if @max_threads < 1

      @state = :running
      @pool = []
      @terminator = Event.new
      @mutex = Mutex.new

      @busy = []
      @idle = []
    end

    def <<(block)
      self.post(&block)
      return self
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') if block.nil?
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
        worker.signal(*args, &block)

        prune_stale_workers
        true
      end
    end

    def running?
      return @state == :running
    end

    def wait_for_termination(timeout)
      return @terminator.wait(timeout.to_i)
    end

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

    def kill
      @mutex.synchronize do
        break if @state == :shutdown
        @state = :shutdown
          @idle.each{|worker| worker.kill }
          @busy.each{|worker| worker.kill }
        @terminator.set
      end
    end

    def length
      @mutex.synchronize do
        @state == :running ? @busy.length + @idle.length : 0
      end
    end
    alias_method :size, :length

    def on_worker_exit(worker)
      @mutex.synchronize do
        @idle.delete(worker)
        @busy.delete(worker)
        if @idle.empty? && @busy.empty? && @state != :running
          @state = :shutdown
          @terminator.set
        end
      end
    end

    def on_end_task(worker)
      @mutex.synchronize do
        break unless @state == :running
        @busy.delete(worker)
        @idle.push(worker)
      end
    end

    protected

    def create_worker_thread
      wrkr = Worker.new(self)
      Thread.new(wrkr, self) do |worker, parent|
        Thread.current.abort_on_exception = false
        worker.run
        parent.on_worker_exit(worker)
      end
      return wrkr
    end

    def prune_stale_workers
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
