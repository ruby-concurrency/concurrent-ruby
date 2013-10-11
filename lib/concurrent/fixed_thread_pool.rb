require 'concurrent/abstract_thread_pool'

module Concurrent

  class FixedThreadPool < AbstractThreadPool

    def initialize(size, opts = {})
      super(opts.merge(max_threads: size))
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') unless block_given?
      return @mutex.synchronize do
        if @state == :running
          while @pool.size < @max_threads
            create_worker_thread
          end
          @queue << [args, block]
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
