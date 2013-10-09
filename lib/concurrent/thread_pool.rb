require 'thread'
require 'functional'

require 'concurrent/event'

behavior_info(:global_thread_pool,
              post: -1,
              :<< => 1)

module Concurrent

  class AbstractThreadPool

    WorkerContext = Struct.new(:status, :idletime, :thread)

    MIN_POOL_SIZE = 1
    MAX_POOL_SIZE = 256

    attr_accessor :max_threads

    def initialize(opts = {})
      @max_threads = opts[:max_threads] || opts[:max] || MAX_POOL_SIZE
      if @max_threads < MIN_POOL_SIZE || @max_threads > MAX_POOL_SIZE
        raise ArgumentError.new("pool size must be from #{MIN_POOL_SIZE} to #{MAX_POOL_SIZE}")
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
        @collector.kill if @collector && @collector.status
        @state = :shuttingdown
        @pool.each{|t| Thread.kill(t.thread) }
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
        @pool.collect do |worker|
          [
            worker.status,
            worker.status == :idle ? delta(worker.idletime, timestamp) : nil,
            worker.thread.status
          ]
        end
      end
    end

    protected

    def timestamp
      return Time.now.to_i
    end

    private

    def create_worker_thread
      context = WorkerContext.new(:idle, timestamp, nil)

      context.thread = Thread.new do
        Thread.current.abort_on_exception = false
        loop do
          task = @queue.pop
          if task == :stop
            @mutex.synchronize do
              context.status = :stopping
            end
            break
          else
            @mutex.synchronize do
              context.status = :working
              @working += 1
            end
            task.last.call(*task.first)
            @mutex.synchronize do
              @working -= 1
              context.status = :idle
              context.idletime = timestamp
            end
          end
        end
        @mutex.synchronize do
          @pool.delete(context)
          if @pool.empty? && @state != :running
            @terminator.set
            @state = :shutdown
          end
        end
      end

      Thread.pass
      run_garbage_collector unless @collector && @collector.alive?
      return context
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
