require 'concurrent/configuration'
require 'thread'

module Concurrent

  # Perform the given operation asynchronously after the given number of seconds.
  #
  # This is a convenience method for posting tasks to the global timer set.
  # It is intended to be simple and easy to use. For greater control use
  # either `TimerSet` or `ScheduledTask` directly.
  #
  # @param [Fixnum] seconds the interval in seconds to wait before executing the task
  #
  # @yield the task to execute
  #
  # @return [Concurrent::ScheduledTask] IVar representing the task
  #
  # @see Concurrent::ScheduledTask
  # @see Concurrent::TimerSet
  #
  # @!macro monotonic_clock_warning
  def timer(seconds, *args, &block)
    raise ArgumentError.new('no block given') unless block_given?
    raise ArgumentError.new('interval must be greater than or equal to zero') if seconds < 0
    Concurrent.configuration.global_timer_set.post(seconds, *args, &block)
  end
  module_function :timer
end
