#!/usr/bin/env ruby

$:.push File.join(File.dirname(__FILE__), '../lib')

require 'concurrent'
require 'benchmark'
require 'rbconfig'

def event_test(clazz, opts = {})
  threads = opts.fetch(:threads, 5)
  tests = opts.fetch(:tests, 100)

  event = clazz.new
  latch = Concurrent::CountDownLatch.new(1)

  print "Testing with #{clazz}...\n"
  stats = Benchmark.measure do

    threads.times do 
      Thread.new do
        loop{ event.wait }
      end
    end

    Thread.new do
      tests.times{ event.set; event.reset }
      latch.count_down
    end

    latch.wait
  end

  print stats
end

puts "Testing with #{RbConfig::CONFIG['ruby_install_name']} #{RUBY_VERSION}"

event_test(Concurrent::Event, threads: 10, tests: 1_000_000)

if defined? Concurrent::CEvent
  event_test(Concurrent::CEvent, threads: 10, tests: 1_000_000)
end
