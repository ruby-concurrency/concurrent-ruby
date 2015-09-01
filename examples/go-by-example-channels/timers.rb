#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Edge::Channel

## Go by Example: Timers
# https://gobyexample.com/timers

timer1 = Channel.timer(2)

~timer1
puts 'Timer 1 expired'

timer2 = Channel.timer(1)
Channel.go do
  ~timer2
  print "Timer 2 expired\n"
end

stop2 = timer2.stop
print "Timer 2 stopped\n" if stop2

expected = <<-STDOUT
Timer 1 expired
Timer 2 stopped
STDOUT
