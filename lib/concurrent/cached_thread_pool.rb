require 'concurrent/abstract_thread_pool'

module Concurrent

  class CachedThreadPool < AbstractThreadPool

    DEFAULT_THREAD_IDLETIME = 60

    def initialize(opts = {})
      @idletime = (opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
      super(opts)
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      return @mutex.synchronize do
        if @state == :running
          @queue << [args, block]
          at_capacity = @pool.empty? || ! @queue.empty? || @working >= @pool.size
          if at_capacity && @pool.length < @max_threads
            @pool << create_worker_thread
          end
          true
        else
          false
        end
      end
    end

    protected

    def dead_worker?(context)
      return context.thread.nil? || context.thread.status == 'aborting' || ! context.thread.status
    end

    def stale_worker?(context)
      if context.status == :idle && @idletime <= (timestamp - context.idletime)
        context.thread.kill
        return true
      else
        return false
      end
    end

    def collect_garbage
      @pool.reject! do |context|
        dead_worker?(context) || stale_worker?(context)
      end
    end
  end
end
