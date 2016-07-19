#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

## Go by Example: Range over Channels
# https://gobyexample.com/range-over-channels

queue = Channel.new(2)
queue << 'one'
queue << 'two'
queue.close

queue.each { |e| puts e }

__END__
one
two
