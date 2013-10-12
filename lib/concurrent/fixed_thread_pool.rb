require 'concurrent/abstract_thread_pool'

module Concurrent

  class FixedThreadPool < AbstractThreadPool

    def initialize(size, opts = {})
      super(opts.merge(max_threads: size))
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
  end
end
