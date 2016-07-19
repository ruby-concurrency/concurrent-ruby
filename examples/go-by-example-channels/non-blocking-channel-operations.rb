#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

## Go by Example: Non-Blocking Channel Operations
# https://gobyexample.com/non-blocking-channel-operations

messages = Channel.new
signals  = Channel.new

Channel.select(messages) do |msg, c|
  case c
  when messages then puts "received message #{msg}"
  else puts 'no message received'
  end
end

# msg = 'hi'
# messages <- msg
# select {
# case messages <- msg:
#     fmt.Println("sent message", msg)
# default:
#     fmt.Println("no message sent")
# }

Channel.select(messages, signals) do |res, c|
  case c
  when messages then puts "received message #{res}"
  when signals  then puts "received signal #{res}"
  else puts 'no activity'
  end
end

__END__
no message received
no message sent
no activity
