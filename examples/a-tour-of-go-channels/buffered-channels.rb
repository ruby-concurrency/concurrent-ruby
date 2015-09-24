#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

## A Tour of Go: Buffered Channels
# https://tour.golang.org/concurrency/3 

ch = Channel.new(size: 2)
ch << 1
ch << 2

puts ~ch
puts ~ch

expected = <<-STDOUT
1
2
STDOUT
