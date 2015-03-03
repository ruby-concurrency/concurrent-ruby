module Concurrent

  if defined?(Process::CLOCK_MONOTONIC)
    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  elsif RUBY_PLATFORM == 'java'
    def monotonic_time
      java.lang.System.nanoTime() / 1_000_000_000.0
    end
  else

    require 'thread'

    # @!visibility private
    GLOBAL_MONOTONIC_CLOCK = Class.new {
      def initialize
        @mutex = Mutex.new
        @correction = 0
        @last_time = Time.now.to_f
      end
      def get_time
        @mutex.synchronize do
          @correction ||= 0 # compensating any back time shifts
          now = Time.now.to_f
          corrected_now = now + @correction
          if @last_time < corrected_now
            return @last_time = corrected_now 
          else
            @correction += @last_time - corrected_now + 0.000_001
            return @last_time = @correction + now
          end
        end
      end
    }.new

    def monotonic_time
      GLOBAL_MONOTONIC_CLOCK.get_time
    end
  end

  module_function :monotonic_time
end
