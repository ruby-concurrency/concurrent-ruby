$:<< 'lib'
require 'rubygems'
require 'concurrent'

demux = Concurrent::DrbDemultiplexer.new
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
