require 'concurrent/abstract_thread_pool'

module Concurrent

  class CachedThreadPool < AbstractThreadPool

    DEFAULT_THREAD_IDLETIME = 60

    def initialize(opts = {})
      @idletime = (opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
      super(opts)
    end

    protected

    def at_post
      at_capacity = @pool.empty? || ! @queue.empty? || Worker.working >= @pool.size
      if at_capacity && @pool.length < @max_threads
        create_worker_thread
      end
    end

    def dead_worker?(worker)
      thread_status = worker.status.last
      return ! thread_status || thread_status == 'aborting'
    end

    def stale_worker?(worker)
      if worker.idle? && worker.idletime >= @idletime
        worker.kill
        return true
      else
        return false
      end
    end

    def collect_garbage
      @pool.reject! do |worker|
        dead_worker?(worker) || stale_worker?(worker)
      end
    end
  end
end
