require 'thread'

module Concurrent

  TimeoutError = Class.new(StandardError)

  def timeout(seconds)

    thread = Thread.new do
      Thread.current[:result] = yield
    end
    success = thread.join(seconds)

    if success
      return thread[:result]
    else
      raise TimeoutError
    end
  ensure
    Thread.kill(thread) unless thread.nil?
  end
  module_function :timeout

end
