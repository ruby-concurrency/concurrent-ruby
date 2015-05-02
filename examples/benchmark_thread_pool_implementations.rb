#!/usr/bin/env ruby

$: << File.expand_path('../../lib', __FILE__)

require 'benchmark'
require 'concurrent/executors'

COUNT = 100_000

EXECUTORS = [
  [Concurrent::JavaCachedThreadPool],
  [Concurrent::JavaFixedThreadPool, 10],
  [Concurrent::JavaSingleThreadExecutor],
  [Concurrent::JavaThreadPoolExecutor]
]

Benchmark.bmbm do |x|
  EXECUTORS.each do |executor_class, *args|
    x.report(executor_class.to_s) do
      if args.empty?
        executor = executor_class.new
      else
        executor = executor_class.new(*args)
      end
      COUNT.times { executor.post{} }
    end
  end
end
