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
SMALL_BMBM = 250

puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts "Long-lived objects"
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts ""

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

puts ""
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts "Short-lived objects"
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts ""

Benchmark.ips do |bm|
  bm.report('future') do
    latch = Concurrent::CountDownLatch.new(IPS_NUM)
    IPS_NUM.times do
      Concurrent::Future.execute { latch.count_down  }
    end
    latch.wait
  end

  async = AsyncClass.new
  bm.report('async') do
    latch = Concurrent::CountDownLatch.new(IPS_NUM)
    IPS_NUM.times { AsyncClass.new.async.foo(latch) }
    latch.wait
  end

  bm.compare!
end

Benchmark.bmbm do |bm|
  bm.report('celluloid') do
    latch = Concurrent::CountDownLatch.new(SMALL_BMBM)
    SMALL_BMBM.times { CelluloidClass.new.async.foo(latch) }
    latch.wait
  end

  bm.report('async') do
    latch = Concurrent::CountDownLatch.new(SMALL_BMBM)
    SMALL_BMBM.times { AsyncClass.new.async.foo(latch) }
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

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Long-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Calculating -------------------------------------
           celluloid    21.000  i/100ms
               async    36.000  i/100ms
-------------------------------------------------
           celluloid    218.207  (±17.0%) i/s -      1.071k
               async    375.318  (± 3.2%) i/s -      1.908k

Comparison:
               async:      375.3 i/s
           celluloid:      218.2 i/s - 1.72x slower

Rehearsal ---------------------------------------------
celluloid   4.150000   0.690000   4.840000 (  4.826509)
async       2.740000   0.010000   2.750000 (  2.762197)
------------------------------------ total: 7.590000sec

                user     system      total        real
celluloid   4.060000   0.680000   4.740000 (  4.734005)
async       2.720000   0.040000   2.760000 (  2.745365)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Short-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Rehearsal ---------------------------------------------
celluloid   0.120000   0.030000   0.150000 (  0.146426)
async       0.080000   0.020000   0.100000 (  0.091462)
------------------------------------ total: 0.250000sec

                user     system      total        real
celluloid   0.160000   0.060000   0.220000 (  0.216363)
async       0.010000   0.010000   0.020000 (  0.015761)

===========================================================
  jruby 1.7.19 (1.9.3p551) 2015-01-29 20786bd on Java HotSpot(TM) 64-Bit Server VM 1.8.0_45-b14 +jit [darwin-x86_64]
===========================================================

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Long-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Calculating -------------------------------------
           celluloid     2.000  i/100ms
               async    20.000  i/100ms
-------------------------------------------------
           celluloid    141.910  (±40.9%) i/s -    508.000
               async    783.468  (±32.4%) i/s -      3.120k

Comparison:
               async:      783.5 i/s
           celluloid:      141.9 i/s - 5.52x slower

Rehearsal ---------------------------------------------
celluloid   5.880000   1.560000   7.440000 (  5.464000)
async       2.800000   0.230000   3.030000 (  1.615000)
----------------------------------- total: 10.470000sec

                user     system      total        real
celluloid   5.660000   1.500000   7.160000 (  5.432000)
async       3.040000   0.250000   3.290000 (  1.749000)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Short-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Rehearsal ---------------------------------------------
celluloid   1.580000   0.120000   1.700000 (  0.612000)
async       0.060000   0.010000   0.070000 (  0.018000)
------------------------------------ total: 1.770000sec

                user     system      total        real
celluloid   0.670000   0.110000   0.780000 (  0.295000)
async       0.030000   0.000000   0.030000 (  0.009000)
