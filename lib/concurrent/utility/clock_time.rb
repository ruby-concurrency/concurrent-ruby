module Concurrent

  if defined?(Process::CLOCK_MONOTONIC)
    def clock_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  elsif RUBY_PLATFORM == 'java'
    def clock_time
      java.lang.System.nanoTime() / 1_000_000_000.0
    end
  else
    def clock_time
      Time.now.to_f
    end
  end

  module_function :clock_time
end
