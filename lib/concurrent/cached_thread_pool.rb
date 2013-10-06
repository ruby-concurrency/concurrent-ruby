require 'thread'
require 'functional'

require 'concurrent/thread_pool'

module Concurrent

  def self.new_cached_thread_pool
    return CachedThreadPool.new
  end

  class CachedThreadPool < ThreadPool
    behavior(:thread_pool)

    DEFAULT_GC_INTERVAL = 60
    DEFAULT_THREAD_IDLETIME = 60

    attr_reader :working

    def initialize(opts = {})
      @gc_interval = (opts[:gc_interval] || DEFAULT_GC_INTERVAL).freeze
      @thread_idletime = (opts[:thread_idletime] || DEFAULT_THREAD_IDLETIME).freeze
      @max_threads = opts[:max_threads] || opts[:max] || MAX_POOL_SIZE

      if @max_threads < MIN_POOL_SIZE || @max_threads > MAX_POOL_SIZE
        raise ArgumentError.new("size must be from #{MIN_POOL_SIZE} to #{MAX_POOL_SIZE}")
      end

      super()
      @working = 0
    end

    def kill
      @status = :killed
      mutex.synchronize do
        @pool.each{|t| Thread.kill(t.thread) }
      end
    end

    def size
      return @pool.length
    end
    alias_method :length, :size

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      if running?
        mutex.synchronize do
          collect_garbage if @pool.empty?
          if @working >= @pool.length && @pool.length < @max_threads
            create_worker_thread
          end
          @queue << [args, block]
        end
        return true
      else
        return false
      end
    end

    # @private
    def status # :nodoc:
      mutex.synchronize do
        @pool.collect do |worker|
          [
            worker.status,
            worker.status == :idle ? delta(worker.idletime, timestamp) : nil,
            worker.thread.status
          ]
        end
      end
    end

    private

    Worker = Struct.new(:status, :idletime, :thread)

    # @private
    def create_worker_thread # :nodoc:
      worker = Worker.new(:idle, timestamp, nil)

      worker.thread = Thread.new(worker) do |me|
        Thread.current.abort_on_exception = false

        loop do
          task = @queue.pop

          mutex.synchronize do
            @working += 1
            me.status = :working
          end

          if task == :stop
            me.status = :stopping
            break
          else
            task.last.call(*task.first)
            mutex.synchronize do
              @working -= 1
              me.status = :idle
              me.idletime = timestamp
            end
          end
        end

        mutex.synchronize do
          @pool.delete(me)
          if @pool.empty?
            @termination.set
            @status = :shutdown unless killed?
          end
        end
      end

      @pool << worker
    end

    # @private
    def collect_garbage # :nodoc:
      @collector = Thread.new do
        Thread.current.abort_on_exception = false
        loop do
          sleep(@gc_interval)
          mutex.synchronize do
            @pool.reject! do |worker|
              worker.thread.status.nil? ||
                (worker.status == :idle && @thread_idletime >= delta(worker.idletime, timestamp))
            end
          end
          @working = @pool.count{|worker| worker.status == :working}
          break if @pool.empty?
        end
      end
    end
  end
end
