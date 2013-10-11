require 'concurrent/abstract_thread_pool'

module Concurrent

  class FixedThreadPool < AbstractThreadPool

    def initialize(size, opts = {})
      super(opts.merge(max_threads: size))
    end

    protected

    def at_post
      while @pool.size < @max_threads
        create_worker_thread
      end
    end

    def collect_garbage
      @pool.reject! {|context| ! context.status.last }
    end
  end
end
