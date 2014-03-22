require 'thread'

require 'concurrent/event'
require 'concurrent/ruby_fixed_thread_pool/worker'

module Concurrent

  class RubyFixedThreadPool

    def initialize(num_threads, opts = {})
      @num_threads = num_threads.to_i
      raise ArgumentError.new('number of threads must be greater than zero') if @num_threads < 1

      @state = :running
      @pool = []
      @terminator = Event.new
      @queue = Queue.new
      @mutex = Mutex.new
    end

    def running?
      return @state == :running
    end

    def wait_for_termination(timeout)
      return @terminator.wait(timeout.to_i)
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
        @state == :running ? @num_threads : 0
      end
    end
    alias_method :size, :length

    def current_length
      @mutex.synchronize do
        @state == :running ? @pool.length : 0
      end
    end
    alias_method :current_size, :current_length

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
      while @pool.length < @num_threads
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
