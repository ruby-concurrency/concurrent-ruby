#!/usr/bin/env ruby

main = Thread.main
t = Thread.new { sleep(2); print "Inside: #{t.inspect}\n" }
3.times { fork { print "Fork #{$$}: #{t.inspect}, #{main.inspect}, #{Thread.main.inspect}\n" } }
t.join

print "\n"

class ThreadMainTester
  attr_reader :main
  def initialize
    @main = Thread.main
  end
end

def log(tester = nil)
  parentlog = tester ? ", parent main #{tester.main.inspect}" : ""
  print "pid #{$$}, Thread.main #{Thread.main.inspect}#{parentlog}\n"
end

TESTS = 3
testers = TESTS.times.collect { ThreadMainTester.new  }
log
testers.each do |tester|
  fork { log(tester) }
end
sleep(1)

__END__

[17:53:58 Jerry ~/Projects/ruby-concurrency/concurrent-ruby (fork-in-the-road)]
$ ./examples/test_threads_and_forks.rb
Fork 2116: #<Thread:0x007fe44c027e60@./examples/test_threads_and_forks.rb:4 dead>, #<Thread:0x007fe44a8c03f8 run>, #<Thread:0x007fe44a8c03f8 run>
Fork 2117: #<Thread:0x007fe44c027e60@./examples/test_threads_and_forks.rb:4 dead>, #<Thread:0x007fe44a8c03f8 run>, #<Thread:0x007fe44a8c03f8 run>
Fork 2118: #<Thread:0x007fe44c027e60@./examples/test_threads_and_forks.rb:4 dead>, #<Thread:0x007fe44a8c03f8 run>, #<Thread:0x007fe44a8c03f8 run>
Inside: #<Thread:0x007fe44c027e60@./examples/test_threads_and_forks.rb:4 run>

pid 2115, Thread.main #<Thread:0x007fe44a8c03f8 run>
pid 2120, Thread.main #<Thread:0x007fe44a8c03f8 run>, parent main #<Thread:0x007fe44a8c03f8 run>
pid 2121, Thread.main #<Thread:0x007fe44a8c03f8 run>, parent main #<Thread:0x007fe44a8c03f8 run>
pid 2122, Thread.main #<Thread:0x007fe44a8c03f8 run>, parent main #<Thread:0x007fe44a8c03f8 run>
