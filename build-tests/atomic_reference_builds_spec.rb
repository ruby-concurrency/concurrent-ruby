require 'benchmark'
require_relative 'example_group_extensions'
require_relative 'platform_helpers'

require 'concurrent/atomics'

def atomic_reference_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  atomic = Concurrent.const_get(clazz.to_s).new
  latch = Concurrent::CountDownLatch.new(threads)

  stats = Benchmark.measure do
    threads.times do |i|
      Thread.new do
        tests.times{ atomic.value = true }
        latch.count_down
      end
    end
    latch.wait
  end
  stats
end

describe Concurrent::Atomic do

  let!(:threads) { 10 }
  let!(:tests) { 1000 }

  describe Concurrent::MutexAtomic do

    specify 'is defined' do
      expect(defined?(Concurrent::MutexAtomic)).to be_truthy
    end

    specify 'runs the benchmarks' do
      stats = atomic_reference_test('MutexAtomic', threads: threads, tests: tests)
      expect(stats).to be_benchmark_results
    end
  end

  if jruby? && 'JRUBY' == ENV['TEST_PLATFORM']

    describe Concurrent::JavaAtomic do

      specify 'Concurrent::JavaAtomic is defined' do
        expect(defined?(Concurrent::JavaAtomic)).to be_truthy
      end

      specify 'runs the benchmarks' do
        stats = atomic_reference_test('JavaAtomic', threads: threads, tests: tests)
        expect(stats).to be_benchmark_results
      end
    end

  else

    specify 'Concurrent::JavaAtomic is not defined' do
      expect(defined?(Concurrent::JavaAtomic)).to be_falsey
    end
  end

  if 'EXT' == ENV['TEST_PLATFORM']

    describe Concurrent::CAtomic do

      specify 'Concurrent::CAtomic is defined' do
        expect(defined?(Concurrent::CAtomic)).to be_truthy
      end

      specify 'runs the benchmarks' do
        stats = atomic_reference_test('CAtomic', threads: threads, tests: tests)
        expect(stats).to be_benchmark_results
      end
    end

  else

    specify 'Concurrent::CAtomic is not defined' do
      expect(defined?(Concurrent::CAtomic)).to be_falsey
    end
  end
end
