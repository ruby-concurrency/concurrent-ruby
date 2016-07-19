#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

## Go by Example: Unbuffered Channel
# https://gobyexample.com/channels

messages = Channel.new

go -> { messages << 'ping' }

msg = messages.recv
puts msg

__END__
ping
