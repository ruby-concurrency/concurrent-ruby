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
w = WaitGroup.new
w.add(5)

1.upto(5) do |i|
  go(lambda do |i, ci|
    j = 1
    ci.each do |v|
      sleep(0.001)
      puts format('%d.%d got %d', i, j, v)
      j += 1
    end
    w.done
  end, i, c)
end

1.upto(25) { |i| c << i }
c.close
w.wait