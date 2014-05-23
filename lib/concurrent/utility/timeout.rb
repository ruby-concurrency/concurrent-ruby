require 'rbconfig'
require 'thread'

require 'concurrent/errors'

module Concurrent

  # Wait the given number of seconds for the block operation to complete.
  #
  # @param [Integer] seconds The number of seconds to wait
  #
  # @return [Object] The result of the block operation
  #
  # @raise [Concurrent::TimeoutError] when the block operation does not complete
  #   in the allotted number of seconds.
  #
  # @note This method is intended to be a simpler and more reliable replacement
  # to the Ruby standard library `Timeout::timeout` method.
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
