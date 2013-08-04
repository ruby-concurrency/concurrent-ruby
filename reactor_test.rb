$:<< 'lib'
require 'rubygems'
require 'concurrent'

reactor = Concurrent::Reactor.new

puts "thread count: #{Thread.list.length}"
puts "running: #{reactor.running?}"

reactor.add_handler(:foo){ 'Foo' }
reactor.add_handler(:bar){ 'Bar' }
reactor.add_handler(:baz){ 'Baz' }
reactor.add_handler(:fubar){ raise StandardError.new('Boom!') }

reactor.stop_on_signal('TERM')

puts "thread count: #{Thread.list.length}"
puts "running: #{reactor.running?}"

t = Thread.new do
  reactor.start
end
t.abort_on_exception = true
sleep(0.1)

puts "thread count: #{Thread.list.length}"
puts "running: #{reactor.running?}"

p reactor.handle(:foo)
p reactor.handle(:bar)
p reactor.handle(:baz)
p reactor.handle(:bogus)
p reactor.handle(:fubar)

puts "thread count: #{Thread.list.length}"
puts "running: #{reactor.running?}"

reactor.stop
t.join

puts "thread count: #{Thread.list.length}"
puts "running: #{reactor.running?}"

