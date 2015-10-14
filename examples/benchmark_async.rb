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
                        31.000  i/100ms
async, global thread pool
                        31.000  i/100ms
-------------------------------------------------
           celluloid    277.834  (± 9.4%) i/s -      1.392k
async, thread per object
                        316.357  (± 1.9%) i/s -      1.612k
async, global thread pool
                        318.707  (± 2.2%) i/s -      1.612k

Comparison:
async, global thread pool:      318.7 i/s
async, thread per object:      316.4 i/s - 1.01x slower
           celluloid:      277.8 i/s - 1.15x slower

Rehearsal -------------------------------------------------------------
celluloid                   4.110000   0.650000   4.760000 (  4.766239)
async, thread per object    3.370000   0.100000   3.470000 (  3.420537)
async, global thread pool   3.460000   0.240000   3.700000 (  3.598044)
--------------------------------------------------- total: 11.930000sec

                                user     system      total        real
celluloid                   4.000000   0.640000   4.640000 (  4.652382)
async, thread per object    3.640000   0.160000   3.800000 (  3.751535)
async, global thread pool   3.440000   0.220000   3.660000 (  3.550602)

===========================================================
jruby 1.7.19 (1.9.3p551) 2015-01-29 20786bd on Java HotSpot(TM) 64-Bit Server VM 1.8.0_45-b14 +jit [darwin-x86_64]
===========================================================

Calculating -------------------------------------
           celluloid     2.000  i/100ms
async, thread per object
                        23.000  i/100ms
async, global thread pool
                        60.000  i/100ms
-------------------------------------------------
           celluloid    155.480  (±38.6%) i/s -    606.000
async, thread per object
                        823.969  (±18.2%) i/s -      3.404k
async, global thread pool
                        852.728  (±14.7%) i/s -      4.140k

Comparison:
async, global thread pool:      852.7 i/s
async, thread per object:      824.0 i/s - 1.03x slower
           celluloid:      155.5 i/s - 5.48x slower

Rehearsal -------------------------------------------------------------
celluloid                   5.640000   1.560000   7.200000 (  5.480000)
async, thread per object    2.660000   0.240000   2.900000 (  1.670000)
async, global thread pool   2.110000   0.240000   2.350000 (  1.360000)
--------------------------------------------------- total: 12.450000sec

                                user     system      total        real
celluloid                   5.650000   1.540000   7.190000 (  5.470000)
async, thread per object    2.350000   0.230000   2.580000 (  1.532000)
async, global thread pool   1.910000   0.220000   2.130000 (  1.272000)
