require 'thread'

require 'concurrent/thread_pool'
require 'concurrent/event'

module Concurrent

  def self.new_fixed_thread_pool(size)
    return FixedThreadPool.new(size)
  end

  class FixedThreadPool < ThreadPool
    behavior(:thread_pool)

    MIN_POOL_SIZE = 1
    MAX_POOL_SIZE = 1024

    def initialize(size)
      super()
      if size < MIN_POOL_SIZE || size > MAX_POOL_SIZE
        raise ArgumentError.new("size must be between #{MIN_POOL_SIZE} and #{MAX_POOL_SIZE}")
      end

      @pool = size.times.collect{ create_worker_thread }
      collect_garbage
    end

    def kill
      mutex.synchronize do
        @status = :killed
        @pool.each{|t| Thread.kill(t) }
      end
    end

    def size
      if running?
        return @pool.length
      else
        return 0
      end
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      if running?
        @queue << [args, block]
        return true
      else
        return false
      end
    end

    # @private
    def status # :nodoc:
      mutex.synchronize do
        @pool.collect{|t| t.status }
      end
    end

    private

    # @private
    def create_worker_thread # :nodoc:
      thread = Thread.new do
        Thread.current.abort_on_exception = false
        loop do
          task = @queue.pop
          if task == :stop
            break
          else
            task.last.call(*task.first)
          end
        end
        @pool.delete(Thread.current)
        if @pool.empty?
          @termination.set
          @status = :shutdown unless killed?
        end
      end

      return thread
    end

    # @private
    def collect_garbage # :nodoc:
      @collector = Thread.new do
        Thread.current.abort_on_exception = false
        sleep(1)
        mutex.synchronize do
          @pool.size.times do |i|
            if @pool[i].status.nil?
              @pool[i] = create_worker_thread
            end
          end
        end
      end
    end
  end
end
