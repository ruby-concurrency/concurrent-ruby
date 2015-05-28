require 'concurrent/configuration'

module Concurrent

  # [DEPRECATED] Perform the given operation asynchronously after
  # the given number of seconds.
  #
  # @param [Fixnum] seconds the interval in seconds to wait before executing the task
  #
  # @yield the task to execute
  #
  # @return [Concurrent::ScheduledTask] IVar representing the task
  #
  # @see Concurrent::ScheduledTask
  #
  # @deprecated use `ScheduledTask` instead
  def timer(seconds, *args, &block)
    warn '[DEPRECATED] use ScheduledTask instead'
    raise ArgumentError.new('no block given') unless block_given?
    raise ArgumentError.new('interval must be greater than or equal to zero') if seconds < 0
    Concurrent.configuration.global_timer_set.post(seconds, *args, &block)
  end
  module_function :timer
end
