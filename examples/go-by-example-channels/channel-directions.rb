#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

## Go by Example: Channel Direction
# https://gobyexample.com/channel-directions

def ping(pings, msg)
  pings = pings.send_only!
  pings << msg
end

def pong(pings, pongs)
  pings = pings.receive_only!
  pongs = pongs.send_only!
  msg = pings.recv
  pongs << msg
end

pings = Channel.new(1)
pongs = Channel.new(1)
ping(pings, 'passed message')
pong(pings, pongs)
puts pongs.recv

__END__
passed message
