require 'concurrent/abstract_thread_pool'

module Concurrent

  class CachedThreadPool < AbstractThreadPool

    DEFAULT_THREAD_IDLETIME = 60

    def initialize(opts = {})
      @idletime = (opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
      raise ArgumentError.new('idletime must be greater than zero') if @idletime <= 0

      super
    end

    def fill_pool
      return unless @state == :running
      if @pool.length < @max_threads && Concurrent::AbstractThreadPool::Worker.busy >= @pool.length
        @pool << create_worker_thread
      end
    end

    def clean_pool
      @pool.reject! do |worker|
        if worker.idle? && worker.idletime >= @idletime
          worker.kill
          true
        else
          worker.dead?
        end
      end
    end
  end
end
