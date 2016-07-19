#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

## Go by Example: Channel Synchronizatio
# https://gobyexample.com/channel-synchronization

def worker(done)
  $stdout.write 'working...'
  sleep 1
  puts 'done'
  done << true
end

done = Channel.new(1)
go -> { worker(done) }

done.recv

__END__
working...
done
