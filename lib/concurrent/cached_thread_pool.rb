require 'concurrent/ruby_cached_thread_pool'

module Concurrent

  if defined? java.util
    require 'concurrent/java_cached_thread_pool'
    CachedThreadPool = Class.new(JavaCachedThreadPool)
  else
    CachedThreadPool = Class.new(RubyCachedThreadPool)
  end
end
