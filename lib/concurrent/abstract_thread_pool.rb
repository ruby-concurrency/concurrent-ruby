require 'thread'

require 'concurrent/event'
require 'concurrent/abstract_thread_pool/worker'

module Concurrent

  class AbstractThreadPool

    MIN_POOL_SIZE = 1
    MAX_POOL_SIZE = 256

    attr_accessor :max_threads

    def initialize(opts = {})
      @max_threads = opts[:max_threads] || opts[:max] || MAX_POOL_SIZE
      if @max_threads < MIN_POOL_SIZE || @max_threads > MAX_POOL_SIZE
        raise ArgumentError.new("size must be from #{MIN_POOL_SIZE} to #{MAX_POOL_SIZE}")
      end

      @state = :running
      @mutex ||= Mutex.new
      @terminator ||= Event.new
      @pool ||= []
      @queue ||= Queue.new
      @working = 0
    end

    def running?
      return @state == :running
    end

    def shutdown
      @mutex.synchronize do
        @collector.kill if @collector && @collector.status
        if @pool.empty?
          @state = :shutdown
          @terminator.set
        else
          @state = :shuttingdown
          @pool.size.times{ @queue << :stop }
        end
      end
      Thread.pass
    end

    def wait_for_termination(timeout = nil)
      return @terminator.wait(timeout)
    end

    def <<(block)
      self.post(&block)
      return self
    end

    def kill
      @mutex.synchronize do
        @state = :shuttingdown
        @collector.kill if @collector && @collector.status
        @pool.each{|worker| worker.kill }
        @terminator.set
      end
      Thread.pass
    end

    def size
      return @mutex.synchronize do
        @state == :running ? @pool.length : 0
      end 
    end
    alias_method :length, :size

    def status
      @mutex.synchronize do
        @pool.collect {|worker| worker.status }
      end
    end

    private

    def create_worker_thread
      @pool << Worker.new(@queue)
      Thread.new(@pool.last) do |worker|
        Thread.current.abort_on_exception = false
        worker.run
        @mutex.synchronize do
          @pool.delete(worker)
          if @pool.empty? && @state != :running
            @terminator.set
            @state = :shutdown
          end
        end
      end
      run_garbage_collector unless @collector && @collector.alive?
    end

    def run_garbage_collector
      @collector = Thread.new do
        Thread.current.abort_on_exception = false
        loop do
          sleep(1)
          @mutex.synchronize { collect_garbage }
        end
      end
      Thread.pass
    end
  end
end
