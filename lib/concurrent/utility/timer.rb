require 'concurrent/configuration'
require 'thread'

module Concurrent

  # Perform the given operation asynchronously after the given number of seconds.
  #
  # @param [Fixnum] seconds the interval in seconds to wait before executing the task
  #
  # @yield the task to execute
  #
  # @return [Boolean] true
  #
  # @!macro monotonic_clock_warning
  def timer(seconds, *args, &block)
    raise ArgumentError.new('no block given') unless block_given?
    raise ArgumentError.new('interval must be greater than or equal to zero') if seconds < 0

    Concurrent.global_timer_set.post(seconds, *args, &block)
    true
  end
  module_function :timer
end
