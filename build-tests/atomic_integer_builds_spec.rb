require 'benchmark'
require_relative 'example_group_extensions'
require_relative 'platform_helpers'

require 'concurrent/atomics'

def atomic_integer_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  atomic = Concurrent.const_get(clazz.to_s).new
  latch = Concurrent::CountDownLatch.new(threads)

  stats = Benchmark.measure do
    threads.times do |i|
      Thread.new do
        tests.times{ atomic.up }
        latch.count_down
      end
    end
    latch.wait
  end
  stats
end

describe Concurrent::AtomicInteger do

  let!(:threads) { 10 }
  let!(:tests) { 1000 }

  unless jruby?
    describe Concurrent::MutexAtomicInteger do

      specify 'is defined' do
        expect(defined?(Concurrent::MutexAtomicInteger)).to be_truthy
      end

      specify 'runs the benchmarks' do
        stats = atomic_integer_test('MutexAtomicInteger', threads: threads, tests: tests)
        expect(stats).to be_benchmark_results
      end
    end
  end


  if 'EXT' == ENV['TEST_PLATFORM'].strip

    describe Concurrent::CAtomicInteger do

      specify 'Concurrent::CAtomicInteger is defined' do
        expect(defined?(Concurrent::CAtomicInteger)).to be_truthy
      end

      specify 'runs the benchmarks' do
        stats = atomic_integer_test('CAtomicInteger', threads: threads, tests: tests)
        expect(stats).to be_benchmark_results
      end
    end

  else

    specify 'Concurrent::CAtomicInteger is not defined' do
      expect(defined?(Concurrent::CAtomicInteger)).to be_falsey
    end
  end
end
