#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Edge::Channel

## Go by Example: Range over Channels
# https://gobyexample.com/range-over-channels 

queue = Channel.new(size: 2) # buffered
queue << 'one'
queue << 'two'
queue.close

queue.each do |elem|
  print "#{elem}\n"
end

expected = <<-STDOUT
one
two
STDOUT

def blocking_variant
  queue = Channel.new(size: 2)
  queue << 'one'
  queue << 'two'

  Channel.go do
    sleep(1)
    queue.close
  end

  queue.each do |elem|
    print "#{elem}\n"
  end
end

def sorting
  count = 10
  queue = Channel.new(size: count)
  count.times { queue << rand(100) }
  queue.close

  puts queue.sort
end
