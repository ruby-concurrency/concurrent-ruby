#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

## Go by Example: Timeouts
# https://gobyexample.com/timeouts

c1 = Channel.new(1)
go lambda {
  sleep(2)
  c1 << 'result 1'
}

Channel.select(c1, t1 = Channel::Timer.after(1)) do |res, c|
  case c
  when c1 then puts res
  when t1 then puts 'timeout 1'
  end
end

c2 = Channel.new(1)
go lambda {
  sleep(2)
  c2 << 'result 2'
}

Channel.select(c2, t2 = Channel::Timer.after(3)) do |res, c|
  case c
  when c2 then puts res
  when t2 then puts 'timeout 1'
  end
end

__END__
timeout 1
result 2
