require 'thread'

require 'concurrent/thread_pool'
require 'functional/utilities'

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
      @gc_interval = opts[:gc_interval] || DEFAULT_GC_INTERVAL
      @thread_idletime = opts[:thread_idletime] || DEFAULT_THREAD_IDLETIME
      super()
      @working = 0
      @mutex = Mutex.new
    end

    def kill
      @status = :killed
      @mutex.synchronize do
        @pool.each{|t| Thread.kill(t.thread) }
      end
    end

    def size
      return @pool.length
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      if running?
        collect_garbage if @pool.empty?
        @mutex.synchronize do
          if @working >= @pool.length
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

    private

    Worker = Struct.new(:status, :idletime, :thread)

    # @private
    def create_worker_thread # :nodoc:
      worker = Worker.new(:idle, timestamp, nil)

      worker.thread = Thread.new(worker) do |me|

        loop do
          task = @queue.pop

          @working += 1
          me.status = :working

          if task == :stop
            me.status = :stopping
            break
          else
            task.last.call(*task.first)
            @working -= 1
            me.status = :idle
            me.idletime = timestamp
          end
        end

        @pool.delete(me)
        if @pool.empty?
          @termination.set
          @status = :shutdown unless killed?
        end
      end

      @pool << worker
    end

    # @private
    def collect_garbage # :nodoc:
      @collector = Thread.new do
        loop do
          sleep(@gc_interval)
          @mutex.synchronize do
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
