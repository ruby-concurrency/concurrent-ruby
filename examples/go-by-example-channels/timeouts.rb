#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Edge::Channel

## Go by Example: Timeouts
# https://gobyexample.com/timeouts

c1 = Channel.new(size: 1) # buffered
Channel.go do
  sleep(2)
  c1 << 'result 1'
end

Channel.select do |s|
  s.take(c1) { |msg| print "#{msg}\n" }
  s.after(1) { print "timeout 1\n" }
end

c2 = Channel.new(size: 1) # buffered
Channel.go do
  sleep(2)
  c2 << 'result 2'
end

Channel.select do |s|
  s.take(c2) { |msg| print "#{msg}\n" }
  s.after(3) { print "timeout 2\n" }
end

expected = <<-STDOUT
timeout 1
result 2
STDOUT
