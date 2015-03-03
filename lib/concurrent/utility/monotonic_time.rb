module Concurrent

  GLOBAL_MONOTONIC_CLOCK = Class.new {

    if defined?(Process::CLOCK_MONOTONIC)
      def get_time(other = 0.0)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - other.to_f
      end
    elsif RUBY_PLATFORM == 'java'
      def get_time(other = 0.0)
        (java.lang.System.nanoTime() / 1_000_000_000.0) - other.to_f
      end
    else

      require 'thread'

      # @!visibility private
      def initialize
        @mutex = Mutex.new
        @correction = 0
        @last_time = Time.now.to_f
      end

      def get_time(other = 0.0)
        @mutex.synchronize {
          @correction ||= 0 # compensating any back time shifts
          now = Time.now.to_f
          corrected_now = now + @correction
          if @last_time < corrected_now
            @last_time = corrected_now 
          else
            @correction += @last_time - corrected_now + 0.000_001
            @last_time = @correction + now
          end
        } - other.to_f
      end
    end
  }.new

  def monotonic_time(other = 0.0)
    GLOBAL_MONOTONIC_CLOCK.get_time(other)
  end
  module_function :monotonic_time
end

__END__

#!/usr/bin/env ruby

# $ ./time_test.rb
# Native: 1735.94062338, Ruby: 1425391307.2322402
#        user     system      total        real
# Native time...
#    0.310000   0.000000   0.310000 (  0.306102)
# Ruby time...
#    1.750000   0.000000   1.750000 (  1.757991)
# Native interval...
#    0.360000   0.010000   0.370000 (  0.358779)
# Ruby interval...
#    1.850000   0.000000   1.850000 (  1.857620)
# Native: 1740.221591108, Ruby: 1425391312.2985182

$: << File.expand_path('./lib', __FILE__)

require 'benchmark'
require 'thread'

class MonotonicClock
  def initialize
    @mutex = Mutex.new
    @correction = 0
    @last_time = Time.now.to_f
  end

  def get_time_native
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def get_interval_native(other)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - other.to_f
  end

  def get_time_ruby
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

  def get_interval_ruby(other)
    get_time_ruby - other.to_f
  end
end

COUNT = 2_000_000
CLOCK = MonotonicClock.new

native_now = CLOCK.get_time_native
ruby_now = CLOCK.get_time_ruby

puts "Native: #{native_now}, Ruby: #{ruby_now}"

Benchmark.bm do |bm|

  puts "Native time..."
  bm.report do
    COUNT.times{ CLOCK.get_time_native }
  end

  puts "Ruby time..."
  bm.report do
    COUNT.times{ CLOCK.get_time_ruby }
  end

  puts "Native interval..."
  bm.report do
    COUNT.times{ CLOCK.get_interval_native(native_now) }
  end

  puts "Ruby interval..."
  bm.report do
    COUNT.times{ CLOCK.get_interval_ruby(ruby_now) }
  end
end

puts "Native: #{CLOCK.get_time_native}, Ruby: #{CLOCK.get_time_ruby}"
