require 'rbconfig'
require 'thread'

module Concurrent

  # Error raised when an operations times out.
  TimeoutError = Class.new(StandardError)

  # Wait the given number of seconds for the block operation to complete.
  #
  # @param [Integer] seconds The number of seconds to wait
  #
  # @return The result of the block operation
  #
  # @raise Concurrent::TimeoutError when the block operation does not complete
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

  # Perform the given operation asynchronously after the given number of seconds.
  #
  # @param [Fixnum] seconds the interval in seconds to wait before executing the task
  # @yield the task to execute
  # @return [Boolean] true
  def timer(seconds)
    raise ArgumentError.new('no block given') unless block_given?
    raise ArgumentError.new('interval must be greater than or equal to zero') if seconds < 0

    Concurrent.configuration.global_timer_pool.post do
      begin
        sleep(seconds)
        yield
      rescue Exception
        # suppress
      end
    end
    true
  end
  module_function :timer
end
