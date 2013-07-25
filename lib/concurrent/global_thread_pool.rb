require 'concurrent/cached_thread_pool'

$GLOBAL_THREAD_POOL ||= Concurrent::CachedThreadPool.new
