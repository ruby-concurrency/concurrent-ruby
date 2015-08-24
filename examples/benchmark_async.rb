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
  bm.report('async') do
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
  bm.report('async') do
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
           celluloid    26.000  i/100ms
               async    47.000  i/100ms
-------------------------------------------------
           celluloid    279.912  (± 6.1%) i/s -      1.404k
               async    478.932  (± 2.1%) i/s -      2.397k

Comparison:
               async:      478.9 i/s
           celluloid:      279.9 i/s - 1.71x slower

Rehearsal ---------------------------------------------
celluloid   4.080000   0.620000   4.700000 (  4.695271)
async       2.280000   0.100000   2.380000 (  2.345327)
------------------------------------ total: 7.080000sec

                user     system      total        real
celluloid   3.910000   0.580000   4.490000 (  4.503884)
async       2.220000   0.190000   2.410000 (  2.340467)

===========================================================
jruby 1.7.19 (1.9.3p551) 2015-01-29 20786bd on Java HotSpot(TM) 64-Bit Server VM 1.8.0_45-b14 +jit [darwin-x86_64]
===========================================================

Calculating -------------------------------------
           celluloid     2.000  i/100ms
               async    32.000  i/100ms
-------------------------------------------------
           celluloid     72.887  (±26.1%) i/s -    334.000
               async      1.822k (±31.6%) i/s -      6.368k

Comparison:
               async:     1821.9 i/s
           celluloid:       72.9 i/s - 25.00x slower

Rehearsal ---------------------------------------------
celluloid   8.890000   1.700000  10.590000 (  5.930000)
async       2.250000   0.150000   2.400000 (  1.283000)
----------------------------------- total: 12.990000sec

                user     system      total        real
celluloid   6.310000   1.530000   7.840000 (  5.817000)
async       1.590000   0.060000   1.650000 (  0.912000)
