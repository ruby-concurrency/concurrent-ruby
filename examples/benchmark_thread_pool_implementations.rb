#!/usr/bin/env ruby

$: << File.expand_path('../../lib', __FILE__)

require 'benchmark'
require 'concurrent/executors'

COUNT = 100_000

EXECUTORS = [
  Concurrent::JavaThreadPoolExecutor
]

def test_executor(executor_class, count)
  executor = executor_class.new
  count.times { executor.post{} }
end

Benchmark.bmbm do |x|
  EXECUTORS.each do |executor_class|
    x.report(executor_class.to_s) { test_executor(executor_class, COUNT) }
  end
end
