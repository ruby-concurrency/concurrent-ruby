require 'thread'

require 'concurrent/event'
require 'concurrent/fixed_thread_pool/worker'

module Concurrent

  class FixedThreadPool

    MIN_POOL_SIZE = 1
    MAX_POOL_SIZE = 256

    attr_accessor :max_threads

    def initialize(size, opts = {})
      @max_threads = size || MAX_POOL_SIZE
      if @max_threads < MIN_POOL_SIZE || @max_threads > MAX_POOL_SIZE
        raise ArgumentError.new("size must be from #{MIN_POOL_SIZE} to #{MAX_POOL_SIZE}")
      end

      @state = :running
      @pool = []
      @terminator = Event.new
      @queue = Queue.new
      @mutex = Mutex.new
    end

    def running?
      return @state == :running
    end

    def wait_for_termination(timeout = nil)
      return @terminator.wait(timeout)
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') if block.nil?
      @mutex.synchronize do
        break false unless @state == :running
        @queue << [args, block]
        clean_pool
        fill_pool
        true
      end
    end

    def <<(block)
      self.post(&block)
      return self
    end

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

    def kill
      @mutex.synchronize do
        break if @state == :shutdown
        @state = :shutdown
        @queue.clear
        drain_pool
        @terminator.set
      end
    end

    def length
      @mutex.synchronize do
        @state == :running ? @pool.length : 0
      end
    end

    def create_worker_thread
      wrkr = Worker.new(@queue, self)
      Thread.new(wrkr, self) do |worker, parent|
        Thread.current.abort_on_exception = false
        worker.run
        parent.on_worker_exit(worker)
      end
      return wrkr
    end

    def fill_pool
      return unless @state == :running
      while @pool.length < @max_threads
        @pool << create_worker_thread
      end
    end

    def clean_pool
      @pool.reject! {|worker| worker.dead? } 
    end

    def drain_pool
      @pool.each {|worker| worker.kill }
      @pool.clear
    end

    def on_start_task(worker)
    end

    def on_end_task(worker)
      @mutex.synchronize do
        break unless @state == :running
        clean_pool
        fill_pool
      end
    end

    def on_worker_exit(worker)
      @mutex.synchronize do
        @pool.delete(worker)
        if @pool.empty? && @state != :running
          @state = :shutdown
          @terminator.set
        end
      end
    end
  end
end
