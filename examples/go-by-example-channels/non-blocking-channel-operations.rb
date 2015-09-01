#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Edge::Channel

## Go by Example: Non-Blocking Channel Operations
# https://gobyexample.com/non-blocking-channel-operations 

messages = Channel.new # unbuffered
signals = Channel.new # unbuffered

Channel.select do |s|
  s.take(messages) { |msg| print "received message #{msg}\n" }
  s.default { print "no message received\n" }
end

msg = 'hi'
Channel.select do |s|
  s.put(messages, msg) { |m| print "sent message #{m}\n" }
  s.default { print "no message sent\n" }
end

Channel.select do |s|
  s.case(messages, :~) { |msg| print "received message #{msg}\n" } # alias for `s.take`
  s.case(signals,  :~) { |sig| print "received signal #{sig}\n" }  # alias for `s.take`
  s.default { print "no activity\n" }
end

expected = <<-STDOUT
no message received
no message sent
no activity
STDOUT
