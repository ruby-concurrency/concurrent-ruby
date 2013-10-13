module Concurrent

  class NullThreadPool

    def self.post(*args)
      Thread.new(*args) do
        Thread.current.abort_on_exception = false
        yield(*args)
      end
      return true
    end

    def post(*args, &block)
      return NullThreadPool.post(*args, &block)
    end

    def <<(block)
      NullThreadPool.post(&block)
      return self
    end
  end

  module UsesGlobalThreadPool

    def self.included(base)
      class << base
        def thread_pool
          @thread_pool || $GLOBAL_THREAD_POOL
        end
        def thread_pool=(pool)
          if pool == $GLOBAL_THREAD_POOL
            @thread_pool = nil
          else
            @thread_pool = pool
          end
        end
      end
    end
  end
end

$GLOBAL_THREAD_POOL ||= Concurrent::NullThreadPool.new
