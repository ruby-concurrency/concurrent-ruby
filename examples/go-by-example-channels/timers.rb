#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

## Go by Example: Timers
# https://gobyexample.com/timers

timer1 = Channel::Timer.new(2)

puts 'Timer 1 expired' if timer1.channel.recv

timer2 = Channel::Timer.new(1)
go -> { print "Timer 2 expired\n" if timer2.recv }

stop2 = timer2.stop
print "Timer 2 stopped\n" if stop2

__END__
Timer 1 expired
Timer 2 stopped
