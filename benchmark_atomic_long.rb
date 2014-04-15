require 'concurrent'
require 'benchmark'

def run_benchmark(atomic)
  puts atomic
  benchmark = Benchmark.measure do
    10_000_000.times do
      atomic.value = 1
    end
  end
  puts benchmark
end

if RUBY_PLATFORM == 'java'
  run_benchmark(Concurrent::JavaAtomicFixnum.new)
elsif defined? Concurrent::CAtomicFixnum
  run_benchmark(Concurrent::CAtomicFixnum.new)
end

run_benchmark(Concurrent::MutexAtomicFixnum.new)
