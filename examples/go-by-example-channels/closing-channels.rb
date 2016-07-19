#!/usr/bin/env ruby

$: << File.expand_path('../../../lib', __FILE__)
require 'concurrent-edge'
Channel = Concurrent::Channel

def go(prc, *args)
  Channel::Runtime.go(prc, *args)
end

## Go by Example: Closing Channels
# https://gobyexample.com/closing-channels

jobs = Channel.new(5)
done = Channel.new

go lambda {
  loop do
    begin
      j = jobs.recv
    rescue Channel::Closed
      puts 'received all jobs'
      done << true
      return
    else
      puts "received job #{j}"
    end
  end
}

1.upto 3 do |j|
  jobs << j
  puts "sent job #{j}"
end
jobs.close
puts 'sent all jobs'

done.recv

__END__
sent job 1
received job 1
sent job 2
received job 2
sent job 3
received job 3
sent all jobs
received all jobs
