#!/usr/bin/env ruby

#$: << File.expand_path('../../lib', __FILE__)

require 'benchmark'
require 'concurrent/executors'

COUNT = 10_000

executors = [
  [Concurrent::CachedThreadPool],
  [Concurrent::FixedThreadPool, 10],
  [Concurrent::SingleThreadExecutor],
  [Concurrent::ThreadPoolExecutor]
]
if Concurrent.on_jruby?
  executors << [Concurrent::SingleThreadExecutor]
  executors << [Concurrent::RubyThreadPoolExecutor]
end

Benchmark.bmbm do |x|
  executors.each do |executor_class, *args|
    x.report(executor_class.to_s) do
      if args.empty?
        executor = executor_class.new
      else
        executor = executor_class.new(*args)
      end
      COUNT.times { executor.post{ nil } }
    end
  end
end
