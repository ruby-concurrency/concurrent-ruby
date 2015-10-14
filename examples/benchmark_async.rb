#!/usr/bin/env ruby

#$: << File.expand_path('../../lib', __FILE__)

require 'benchmark'
require 'benchmark/ips'

require 'concurrent'
require 'celluloid'

class CelluloidClass
  include Celluloid
  def foo(latch = nil)
    latch.count_down if latch
  end
end

class AsyncClass
  include Concurrent::Async
  def foo(latch = nil)
    latch.count_down if latch
  end
end

class AsyncAlternateClass
  include Concurrent::Async
  def foo(latch = nil)
    latch.count_down if latch
  end
end

IPS_NUM = 100
BMBM_NUM = 100_000

Benchmark.ips do |bm|
  celluloid = CelluloidClass.new
  bm.report('celluloid') do
    latch = Concurrent::CountDownLatch.new(IPS_NUM)
    IPS_NUM.times { celluloid.async.foo(latch) }
    latch.wait
  end

  async = AsyncClass.new
  bm.report('async, thread per object') do
    latch = Concurrent::CountDownLatch.new(IPS_NUM)
    IPS_NUM.times { async.async.foo(latch) }
    latch.wait
  end

  async = AsyncAlternateClass.new
  bm.report('async, global thread pool') do
    latch = Concurrent::CountDownLatch.new(IPS_NUM)
    IPS_NUM.times { async.async.foo(latch) }
    latch.wait
  end

  bm.compare!
end

Benchmark.bmbm do |bm|
  celluloid = CelluloidClass.new
  bm.report('celluloid') do
    latch = Concurrent::CountDownLatch.new(BMBM_NUM)
    BMBM_NUM.times { celluloid.async.foo(latch) }
    latch.wait
  end

  async = AsyncClass.new
  bm.report('async, thread per object') do
    latch = Concurrent::CountDownLatch.new(BMBM_NUM)
    BMBM_NUM.times { async.async.foo(latch) }
    latch.wait
  end

  async = AsyncAlternateClass.new
  bm.report('async, global thread pool') do
    latch = Concurrent::CountDownLatch.new(BMBM_NUM)
    BMBM_NUM.times { async.async.foo(latch) }
    latch.wait
  end
end

__END__

===========================================================
Async Benchmarks
===========================================================

Computer:

* OS X Yosemite
  - Version 10.10.4
* MacBook Pro
  - Retina, 13-inch, Early 2015
* Processor 3.1 GHz Intel Core i7
* Memory 16 GB 1867 MHz DDR3
* Physical Volumes:
  - Apple SSD SM0512G
  - 500 GB

===========================================================
ruby 2.2.2p95 (2015-04-13 revision 50295) [x86_64-darwin14]
===========================================================

Calculating -------------------------------------
           celluloid    24.000  i/100ms
async, thread per object
                        30.000  i/100ms
async, global thread pool
                        31.000  i/100ms
-------------------------------------------------
           celluloid    242.345  (±10.7%) i/s -      1.200k
async, thread per object
                        316.387  (± 2.5%) i/s -      1.590k
async, global thread pool
                        318.200  (± 1.6%) i/s -      1.612k

Comparison:
async, global thread pool:      318.2 i/s
async, thread per object:      316.4 i/s - 1.01x slower
           celluloid:      242.3 i/s - 1.31x slower

Rehearsal -------------------------------------------------------------
celluloid                   4.170000   0.630000   4.800000 (  4.812120)
async, thread per object    3.400000   0.110000   3.510000 (  3.452749)
async, global thread pool   3.410000   0.070000   3.480000 (  3.455878)
--------------------------------------------------- total: 11.790000sec

                                user     system      total        real
celluloid                   4.080000   0.620000   4.700000 (  4.687752)
async, thread per object    3.380000   0.160000   3.540000 (  3.469882)
async, global thread pool   3.380000   0.050000   3.430000 (  3.426759)
