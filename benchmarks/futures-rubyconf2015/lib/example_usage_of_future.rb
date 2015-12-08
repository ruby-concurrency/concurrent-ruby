require_relative 'mutex_future'
require 'thread'

# prints seconds and the value
def timed_puts(value)
  puts format('%2d: %s', Time.now.sec, value)
end

## Simple background processing ##

WORKER_QUEUE = Queue.new

workers = Array.new(2) do
  Thread.new do
    while true
      sleep 1.5 # simulate slow computation

      # blocking
      job, future = WORKER_QUEUE.pop

      result = job.call
      future.fulfill result

      timed_puts result
    end
  end
end

def async(&block)
  future = MutexFuture.new
  WORKER_QUEUE << [block, future]
  future
end

jobs = Array.new(5) { |i| async { i*2 } }
timed_puts jobs.map(&:class).inspect
# blocks
timed_puts jobs.map(&:value).inspect

