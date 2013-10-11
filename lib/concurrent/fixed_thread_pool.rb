require 'concurrent/thread_pool'

module Concurrent

  class FixedThreadPool < AbstractThreadPool

    def initialize(size, opts = {})
      super(opts.merge(max_threads: size))
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      return @mutex.synchronize do
        if @state == :running
          @queue << [args, block]
          @pool << create_worker_thread if @pool.size < @max_threads
          true
        else
          false
        end
      end
    end

    protected

    def collect_garbage
      @pool.reject! {|context| ! context.status }
    end
  end
end
