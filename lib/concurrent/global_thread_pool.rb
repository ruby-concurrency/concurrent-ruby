require 'concurrent/cached_thread_pool'

$GLOBAL_THREAD_POOL ||= Concurrent::CachedThreadPool.new

module Concurrent

  module UsesGlobalThreadPool

    def self.included(base)
      class << base
        attr_accessor :thread_pool
      end
      base.thread_pool = $GLOBAL_THREAD_POOL
    end
  end
end
