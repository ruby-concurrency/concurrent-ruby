#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

## Go by Example: Channel Buffering
# https://gobyexample.com/channel-buffering

messages = Channel.new(2)

messages << 'buffered'
messages << 'channel'

puts messages.recv
puts messages.recv

__END__
buffered
channel
