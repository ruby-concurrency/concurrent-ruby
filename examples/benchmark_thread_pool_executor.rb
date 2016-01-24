#!/usr/bin/env ruby

$: << File.expand_path('../../lib', __FILE__)

require 'benchmark'
require 'benchmark/ips'
require 'concurrent'

IPS_JOB_COUNT = 250_000
BM_JOB_COUNT = 100_000
BM_TEST_COUNT = 3

OPTIONS = {
  max_threads: 1,
  max_queue: [BM_JOB_COUNT, IPS_JOB_COUNT].max + 2,
  fallback_policy: :abort
}

class DollarDollarThreadPoolExecutor < Concurrent::ThreadPoolExecutor
  def ns_initialize(opts)
    super(opts)
    @ruby_pid = $$
  end

  private

  def ns_execute(*args, &task)
    ns_reset_if_forked
    super
  end

  def ns_reset_if_forked
    if $$ != @ruby_pid
      @queue.clear
      @ready.clear
      @pool.clear
      @ruby_pid = $$
    end
  end
end

executor = DollarDollarThreadPoolExecutor.new
20.times.map { Concurrent::Future.execute(executor: executor) { 1 } }.each(&:wait!)
print "Executor is idle\n"
fork do
  print "Posting forked job...\n"
  Concurrent::Future.execute(executor: executor) { 7 }.wait!
  print "Done\n"
end

sleep(2)
print "\n"

EXECUTORS = [
  Concurrent::ThreadPoolExecutor,
  DollarDollarThreadPoolExecutor
]

def warmup(executor_class)
  executor = executor_class.new(OPTIONS)
  latch = Concurrent::CountDownLatch.new
  executor.post{ latch.count_down }
  latch.wait

  return executor
end

def test(executor, job_count)
  latch = Concurrent::CountDownLatch.new
  job_count.times { executor.post{ nil } }
  executor.post{ latch.count_down }
  latch.wait
end

Benchmark.bmbm do |bm|
  EXECUTORS.each do |executor_class|
    executor = warmup(executor_class)
    BM_TEST_COUNT.times do |i|
      bm.report("#{executor_class.to_s} ##{i + 1}") do
        test(executor, BM_JOB_COUNT)
      end
    end
  end
end

print "\n\n"

Benchmark.ips do |bm|
  EXECUTORS.each do |executor_class|
    executor = warmup(executor_class)
    bm.report(executor_class.to_s) do
      test(executor, IPS_JOB_COUNT)
    end
  end

  bm.compare!
end

__END__
MacBook Pro (Retina, 15-inch, Mid 2015)
Processor 2.8 GHz Intel Core i7
Memory 16 GB 1600 MHz DDR3

[09:29:24 jerry.dantonio ~/Projects/FOSS/concurrent-ruby (fork-in-the-road)]
$ ./examples/benchmark_thread_pool_executor.rb
Executor is idle
Posting forked job...
Done

Rehearsal ---------------------------------------------------------------------
Concurrent::ThreadPoolExecutor #1   0.570000   0.290000   0.860000 (  0.697221)
Concurrent::ThreadPoolExecutor #2   0.600000   0.280000   0.880000 (  0.721201)
Concurrent::ThreadPoolExecutor #3   0.500000   0.170000   0.670000 (  0.576821)
DollarDollarThreadPoolExecutor #1   0.630000   0.340000   0.970000 (  0.771321)
DollarDollarThreadPoolExecutor #2   0.550000   0.240000   0.790000 (  0.645324)
DollarDollarThreadPoolExecutor #3   0.500000   0.170000   0.670000 (  0.569596)
------------------------------------------------------------ total: 4.840000sec

                                        user     system      total        real
Concurrent::ThreadPoolExecutor #1   0.520000   0.320000   0.840000 (  0.627584)
Concurrent::ThreadPoolExecutor #2   0.480000   0.170000   0.650000 (  0.540811)
Concurrent::ThreadPoolExecutor #3   0.460000   0.120000   0.580000 (  0.504568)
DollarDollarThreadPoolExecutor #1   0.530000   0.250000   0.780000 (  0.645633)
DollarDollarThreadPoolExecutor #2   0.500000   0.220000   0.720000 (  0.585540)
DollarDollarThreadPoolExecutor #3   0.490000   0.170000   0.660000 (  0.560775)


Calculating -------------------------------------
Concurrent::ThreadPoolExecutor
                         1.000  i/100ms
DollarDollarThreadPoolExecutor
                         1.000  i/100ms
-------------------------------------------------
Concurrent::ThreadPoolExecutor
                          0.631  (± 0.0%) i/s -      4.000  in   6.425371s
DollarDollarThreadPoolExecutor
                          0.644  (± 0.0%) i/s -      4.000  in   6.279399s

Comparison:
DollarDollarThreadPoolExecutor:        0.6 i/s
Concurrent::ThreadPoolExecutor:        0.6 i/s - 1.02x slower

