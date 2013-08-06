$:<< 'lib'
require 'rubygems'
require 'concurrent'

require 'drb/drb'
require 'socket'

require 'faker'
require 'functional'

DRB_URI = 'druby://localhost:12345'
DRB_ACL = %w{allow all}
#DRB_ACL = %w{deny all allow 127.0.0.1}

TCP_HOST = '127.0.0.1'
TCP_PORT = 12345

def with_commas(n)
  n.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
end

###############################################################################
# TcpSyncDemux

def kill_tcp_echo_server
  there = TCPSocket.open(TCP_HOST, TCP_PORT)
  there.puts(Concurrent::TcpSyncDemux.format_message(:kill))
  there.close
  there = nil
end

def tcp_echo_test(count, verbose = true)
  there = TCPSocket.open(TCP_HOST, TCP_PORT)

  good = 0

  duration, result = timer do
    count.times do |i|
      message = Faker::Company.bs
      puts "Sending  '#{message}'" if verbose
      there.puts(Concurrent::TcpSyncDemux.format_message(:echo, message))
      result, echo = Concurrent::TcpSyncDemux.get_message(there)
      echo = echo.first
      puts "Received '#{echo}'" if verbose
      good += 1 if echo == message
    end
  end

  there.close
  there = nil

  messages_per_second = count / duration
  success_rate = good / count.to_f * 100.0

  puts "Sent #{count} messages. Received #{good} good responses and #{count - good} bad."
  puts "The total processing time was %0.3f seconds." % duration
  puts "That's %i messages per second with a %0.1f success rate." % [messages_per_second, success_rate]
  puts "And we're done!"
end

def tcp_echo_server(verbose = true)
  demux = Concurrent::TcpSyncDemux.new(host: TCP_HOST, port: TCP_PORT)
  reactor = Concurrent::Reactor.new(demux)

  count = 0
  reactor.add_handler(:echo) do |*args|
    puts "Received: '#{args.first}'" if verbose
    count += 1
    args.first
  end

  reactor.add_handler(:kill) do
    reactor.stop
  end

  reactor.stop_on_signal('TERM', 'INT')

  puts 'Starting the reactor...'
  reactor.start

  puts 'Done!'
end

###############################################################################
# DRbAsyncDemux

def kill_drb_echo_server
  there = DRbObject.new_with_uri(DRB_URI)
  there.kill
  there = nil
end

def drb_echo_test(count, verbose = true)
  there = DRbObject.new_with_uri(DRB_URI)

  good = 0

  duration, result = timer do
    count.times do |i|
      message = Faker::Company.bs
      puts "Sending  '#{message}'" if verbose
      echo = there.echo(message)
      puts "Received '#{echo}'" if verbose
      good += 1 if echo == message
      #puts "#{with_commas(i+1)}..." if (i+1) % 1000 == 0
    end
  end

  there = nil

  messages_per_second = count / duration
  success_rate = good / count.to_f * 100.0

  puts "Sent #{count} messages. Received #{good} good responses and #{count - good} bad."
  puts "The total processing time was %0.3f seconds." % duration
  puts "That's %i messages per second with a %0.1f success rate." % [messages_per_second, success_rate]
  puts "And we're done!"
end

def drb_echo_server(verbose = true)
  demux = Concurrent::DRbAsyncDemux.new(uri: DRB_URI, acl: DRB_ACL)
  reactor = Concurrent::Reactor.new(demux)

  count = 0
  reactor.add_handler(:echo) do |message|
    puts "Received: '#{message}'" if verbose
    count += 1
    #puts "#{with_commas(count)}..." if count % 1000 == 0
    message
  end

  reactor.add_handler(:kill) do
    reactor.stop
  end

  puts 'Starting the reactor...'
  reactor.start

  puts 'Done!'
end

###############################################################################
# Console Application - Reactor Test

if __FILE__ == $0

  demux = Concurrent::DRbAsyncDemux.new
  reactor = Concurrent::Reactor.new(demux)

  puts "running: #{reactor.running?}"

  reactor.add_handler(:foo){ 'Foo' }
  reactor.add_handler(:bar){ 'Bar' }
  reactor.add_handler(:baz){ 'Baz' }
  reactor.add_handler(:fubar){ raise StandardError.new('Boom!') }

  reactor.stop_on_signal('INT', 'TERM')

  puts "running: #{reactor.running?}"

  p reactor.handle(:foo)

  t = Thread.new do
    reactor.start
  end
  t.abort_on_exception = true
  sleep(0.1)

  puts "running: #{reactor.running?}"

  p reactor.handle(:foo)
  p reactor.handle(:bar)
  p reactor.handle(:baz)
  p reactor.handle(:bogus)
  p reactor.handle(:fubar)

  puts "running: #{reactor.running?}"

  reactor.stop
  t.join

  p reactor.handle(:foo)

  puts "running: #{reactor.running?}"
end
