$:.push File.join(File.dirname(__FILE__), 'lib')

require 'concurrent'
require 'benchmark'

def event_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  event = clazz.new
  latch = Concurrent::CountDownLatch.new(1)

  print "Testing with #{clazz}...\n"
  stats = Benchmark.measure do

    threads.times do 
      Thread.new do
        loop{ event.wait }
      end
    end

    Thread.new do
      tests.times{ event.set; event.reset }
      latch.count_down
    end

    latch.wait
  end

  print stats
end

event_test(Concurrent::Event, threads: 10, tests: 1_000_000)

if defined? Concurrent::CEvent
  event_test(Concurrent::CEvent, threads: 10, tests: 1_000_000)
end

# About This Mac
# Processor 2.93 GHz Intel Core 2 Duo
# Memory 8 GB 1067 MHz DDR3

# ruby 2.1.1p76 (2014-02-24 revision 45161) [x86_64-darwin13.0]
#
# Testing with Concurrent::Event...
#=> 30.000000  73.960000 103.960000 ( 68.789397)
#
# Testing with Concurrent::CEvent...
#=> 18.550000  36.160000  54.710000 ( 39.766862)

# jruby 1.7.11 (1.9.3p392) 2014-02-24 86339bb on Java HotSpot(TM) 64-Bit Server VM 1.6.0_65-b14-462-11M4609 [darwin-x86_64]
#
# Testing with Concurrent::Event...
#=> 24.880000  14.500000  39.380000 ( 25.637000)
