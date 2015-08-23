#!/usr/bin/env ruby

$: << File.expand_path('../../lib', __FILE__)

require 'benchmark'
require 'benchmark/ips'

require 'concurrent'
require 'celluloid'

class CelluloidClass
  include Celluloid
  def foo
  end
  def bar(latch)
    latch.count_down
  end
end

class AsyncClass
  include Concurrent::Async
  def foo
  end
  def bar(latch)
    latch.count_down
  end
end

IPS_NUM = 100
BMBM_NUM = 100_000

Benchmark.ips do |bm|
  latch = Concurrent::CountDownLatch.new(1)
  celluloid = CelluloidClass.new
  bm.report('celluloid') do
    IPS_NUM.times { celluloid.async.foo }
    celluloid.bar(latch)
    latch.wait
  end

  async = AsyncClass.new
  latch = Concurrent::CountDownLatch.new(1)
  bm.report('async') do
    IPS_NUM.times { async.async.foo }
    async.bar(latch)
    latch.wait
  end

  bm.compare!
end

#Benchmark.bmbm do |bm|
  #bm.report('celluloid') do
  #end
  #bm.report('async') do
  #end
#end
