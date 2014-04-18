require 'concurrent'
require 'benchmark'

def atomic_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  num = clazz.new
  latch = Concurrent::CountDownLatch.new(threads)

  stats = Benchmark.measure do
    threads.times do |i|
      Thread.new do
        print "Starting thread #{i+1}...\n"
        tests.times{ num.up }
        latch.count_down
        print "Thread #{i+1} done.\n"
      end
    end

    print "Waitning for the latch...\n"
    latch.wait
  end
  print "#{stats}\n"
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
#=> 23.050000  62.430000  85.480000 ( 60.877730)
#=> 1.290000   0.000000   1.290000 (  1.295110)

# jruby 1.7.11 (1.9.3p392) 2014-02-24 86339bb on Java HotSpot(TM) 64-Bit Server VM 1.6.0_65-b14-462-11M4609 [darwin-x86_64]
#=> 13.410000   7.510000  20.920000 ( 13.234000)
#=> 4.130000   0.060000   4.190000 (  2.254000)
