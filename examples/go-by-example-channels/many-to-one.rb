#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel
WaitGroup = Concurrent::WaitGroup

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

# http://stackoverflow.com/questions/15715605/multiple-goroutines-listening-on-one-channel

c = Channel.new

1.upto(5) do |i|
  go(lambda do |i, co|
    1.upto(5) do |j|
      co << format('hi from %d.%d', i, j)
    end
  end, i, c)
end

25.times { puts c.recv }
