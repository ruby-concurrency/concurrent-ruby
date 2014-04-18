$:.push File.join(File.dirname(__FILE__), 'lib')

require 'concurrent'
require 'benchmark'

def atomic_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  num = clazz.new
  latch = Concurrent::CountDownLatch.new(threads)

  print "Testing with #{clazz}...\n"
  stats = Benchmark.measure do
    threads.times do |i|
      Thread.new do
        tests.times{ num.up }
        latch.count_down
      end
    end
    latch.wait
  end
  print stats
end

atomic_test(Concurrent::MutexAtomicFixnum, threads: 10, tests: 1_000_000)

if defined? Concurrent::CAtomicFixnum
  atomic_test(Concurrent::CAtomicFixnum, threads: 10, tests: 1_000_000)
elsif RUBY_PLATFORM == 'java'
  atomic_test(Concurrent::JavaAtomicFixnum, threads: 10, tests: 1_000_000)
end

# About This Mac
# Processor 2.93 GHz Intel Core 2 Duo
# Memory 8 GB 1067 MHz DDR3

# ruby 2.1.1p76 (2014-02-24 revision 45161) [x86_64-darwin13.0]
#
# Testing with Concurrent::MutexAtomicFixnum...
#=> 21.180000  55.370000  76.550000 ( 54.700031)
#
# Testing with Concurrent::CAtomicFixnum...
# with GCC atomic operations
#=> 1.270000   0.000000   1.270000 (  1.273004)
#
# Testing with Concurrent::CAtomicFixnum...
# with pthread mutex
#=> 1.980000   0.000000   1.980000 (  1.984493)

# jruby 1.7.11 (1.9.3p392) 2014-02-24 86339bb on Java HotSpot(TM) 64-Bit Server VM 1.6.0_65-b14-462-11M4609 [darwin-x86_64]
#
# Testing with Concurrent::MutexAtomicFixnum...
#=> 12.060000   5.760000  17.820000 ( 11.731000)
#
# Testing with Concurrent::JavaAtomicFixnum...
#=> 3.940000   0.070000   4.010000 (  2.118000)
