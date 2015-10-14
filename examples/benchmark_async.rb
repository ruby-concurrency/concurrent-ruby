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
  include Concurrent::AsyncAlternate
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

puts ""
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts "Short-lived objects"
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts ""

Benchmark.bmbm do |bm|
  bm.report('celluloid') do
    latch = Concurrent::CountDownLatch.new(SMALL_BMBM)
    SMALL_BMBM.times { CelluloidClass.new.async.foo(latch) }
    latch.wait
  end

  bm.report('async, global thread pool') do
    latch = Concurrent::CountDownLatch.new(SMALL_BMBM)
    SMALL_BMBM.times { AsyncAlternateClass.new.async.foo(latch) }
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
           celluloid    24.000  i/100ms
async, thread per object
                        36.000  i/100ms
async, global thread pool
                        36.000  i/100ms
-------------------------------------------------
           celluloid    270.238  (±10.4%) i/s -      1.344k
async, thread per object
                        366.529  (± 3.3%) i/s -      1.836k
async, global thread pool
                        365.264  (± 3.0%) i/s -      1.836k

Comparison:
async, thread per object:      366.5 i/s
async, global thread pool:      365.3 i/s - 1.00x slower
           celluloid:      270.2 i/s - 1.36x slower

Rehearsal -------------------------------------------------------------
celluloid                   4.110000   0.670000   4.780000 (  4.784982)
async, thread per object    3.050000   0.090000   3.140000 (  3.128709)
async, global thread pool   2.960000   0.020000   2.980000 (  2.981984)
--------------------------------------------------- total: 10.900000sec

                                user     system      total        real
celluloid                   4.220000   0.700000   4.920000 (  4.955064)
async, thread per object    3.000000   0.060000   3.060000 (  3.055045)
async, global thread pool   3.150000   0.060000   3.210000 (  3.240574)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Short-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Rehearsal -------------------------------------------------------------
celluloid                   0.180000   0.050000   0.230000 (  0.220111)
async, global thread pool   0.090000   0.020000   0.110000 (  0.111569)
---------------------------------------------------- total: 0.340000sec

                                user     system      total        real
celluloid                   0.240000   0.120000   0.360000 (  0.350697)
async, global thread pool   0.010000   0.000000   0.010000 (  0.013509)

===========================================================
  jruby 1.7.19 (1.9.3p551) 2015-01-29 20786bd on Java HotSpot(TM) 64-Bit Server VM 1.8.0_45-b14 +jit [darwin-x86_64]
===========================================================

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Long-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Calculating -------------------------------------
           celluloid     2.000  i/100ms
async, thread per object
                        24.000  i/100ms
async, global thread pool
                        48.000  i/100ms
-------------------------------------------------
           celluloid    130.115  (±40.7%) i/s -    492.000
async, thread per object
                        896.257  (±17.6%) i/s -      3.984k
async, global thread pool
                        926.262  (±11.0%) i/s -      4.560k

Comparison:
async, global thread pool:      926.3 i/s
async, thread per object:      896.3 i/s - 1.03x slower
           celluloid:      130.1 i/s - 7.12x slower

Rehearsal -------------------------------------------------------------
celluloid                   5.800000   1.590000   7.390000 (  5.306000)
async, thread per object    2.880000   0.190000   3.070000 (  1.601000)
async, global thread pool   2.150000   0.130000   2.280000 (  1.172000)
--------------------------------------------------- total: 12.740000sec

                                user     system      total        real
celluloid                   5.590000   1.520000   7.110000 (  5.391000)
async, thread per object    2.480000   0.160000   2.640000 (  1.364000)
async, global thread pool   1.850000   0.130000   1.980000 (  1.008000)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Short-lived objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Rehearsal -------------------------------------------------------------
celluloid                   1.530000   0.140000   1.670000 (  0.597000)
async, global thread pool   0.060000   0.000000   0.060000 (  0.018000)
---------------------------------------------------- total: 1.730000sec

                                user     system      total        real
celluloid                   1.160000   0.160000   1.320000 (  0.431000)
async, global thread pool   0.020000   0.000000   0.020000 (  0.009000)
