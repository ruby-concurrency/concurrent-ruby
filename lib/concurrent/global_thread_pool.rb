require 'concurrent/cached_thread_pool'

$GLOBAL_THREAD_POOL ||= Concurrent::CachedThreadPool.new

module Concurrent

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
