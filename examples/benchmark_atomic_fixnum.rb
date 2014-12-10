#!/usr/bin/env ruby

$:.push File.join(File.dirname(__FILE__), '../lib')

require 'concurrent/atomics'
require 'benchmark'
require 'rbconfig'

def atomic_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  num = clazz.new
  latch = Concurrent::CountDownLatch.new(threads)

  print "Testing with #{clazz}...\n"
  stats = Benchmark.measure do
    threads.times do |i|
      Thread.new do
        tests.times{ num.up }
        latch.count_down
      end
    end
    latch.wait
  end
  print stats
end

puts "Testing with #{RbConfig::CONFIG['ruby_install_name']} #{RUBY_VERSION}"

atomic_test(Concurrent::MutexAtomicFixnum, threads: 10, tests: 1_000_000)

if defined? Concurrent::CAtomicFixnum
  atomic_test(Concurrent::CAtomicFixnum, threads: 10, tests: 1_000_000)
elsif RUBY_PLATFORM == 'java'
  atomic_test(Concurrent::JavaAtomicFixnum, threads: 10, tests: 1_000_000)
end
