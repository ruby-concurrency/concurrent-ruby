require 'concurrent/ruby_fixed_thread_pool'

module Concurrent

  if defined? java.util
    require 'concurrent/java_fixed_thread_pool'
    FixedThreadPool = Class.new(JavaFixedThreadPool)
  else
    FixedThreadPool = Class.new(RubyFixedThreadPool)
  end
end
