# Concurrent Ruby [![Build Status](https://secure.travis-ci.org/jdantonio/concurrent-ruby.png)](https://travis-ci.org/jdantonio/concurrent-ruby?branch=master) [![Coverage Status](https://coveralls.io/repos/jdantonio/concurrent-ruby/badge.png)](https://coveralls.io/r/jdantonio/concurrent-ruby) [![Dependency Status](https://gemnasium.com/jdantonio/concurrent-ruby.png)](https://gemnasium.com/jdantonio/concurrent-ruby)

***NOTE:*** *A few API updates in v0.5.0 are not backward-compatible. Please see the [release notes](https://github.com/jdantonio/concurrent-ruby/wiki/API-Updates-in-v0.5.0).*

Modern concurrency tools for Ruby. Inspired by
[Erlang](http://www.erlang.org/doc/reference_manual/processes.html),
[Clojure](http://clojure.org/concurrent_programming),
[Scala](http://www.scala-lang.org/api/current/index.html#scala.actors.Actor),
[Haskell](http://www.haskell.org/haskellwiki/Applications_and_libraries/Concurrency_and_parallelism#Concurrent_Haskell),
[F#](http://blogs.msdn.com/b/dsyme/archive/2010/02/15/async-and-parallel-design-patterns-in-f-part-3-agents.aspx),
[C#](http://msdn.microsoft.com/en-us/library/vstudio/hh191443.aspx),
[Java](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/package-summary.html),
and classic concurrency patterns.

The design goals of this gem are:

* Stay true to the spirit of the languages providing inspiration
* But implement in a way that makes sense for Ruby
* Keep the semantics as idiomatic Ruby as possible
* Support features that make sense in Ruby
* Exclude features that don't make sense in Ruby
* Be small, lean, and loosely coupled

## Features & Documentation

Please see the [Concurrent Ruby Wiki](https://github.com/jdantonio/concurrent-ruby/wiki) for more information
or join our [mailing list](http://groups.google.com/group/concurrent-ruby).

There are many concurrency abstractions in this library. These abstractions can be broadly categorized
into several general categories:

* Asynchronous concurrency abstractions including [Actor](https://github.com/jdantonio/concurrent-ruby/wiki/Actor),
  [Agent](https://github.com/jdantonio/concurrent-ruby/wiki/Agent), [Channel](https://github.com/jdantonio/concurrent-ruby/wiki/Channel),
  [Future](https://github.com/jdantonio/concurrent-ruby/wiki/Future), [Promise](https://github.com/jdantonio/concurrent-ruby/wiki/Promise),
  [ScheculedTask](https://github.com/jdantonio/concurrent-ruby/wiki/ScheduledTask),
  and [TimerTask](https://github.com/jdantonio/concurrent-ruby/wiki/TimerTask) 
* Erlang-inspired [Supervisor](https://github.com/jdantonio/concurrent-ruby/wiki/Supervisor) and other lifecycle classes/mixins
  for managing long-running threads
* Thread-save variables including [M-Structures](https://github.com/jdantonio/concurrent-ruby/wiki/MVar-(M-Structure)),
  [thread-local variables](https://github.com/jdantonio/concurrent-ruby/wiki/ThreadLocalVar), and atomic counters
* Thread synchronization classes and algorithms including [dataflow](https://github.com/jdantonio/concurrent-ruby/wiki/Dataflow), 
  timeout, condition, countdown latch, dependency counter, and event
* Java-inspired [thread pools](https://github.com/jdantonio/concurrent-ruby/wiki/Thread%20Pools)
* And many more...

### Semantic Versioning

This gem adheres to the rules of [semantic versioning](http://semver.org/).

### Supported Ruby versions

MRI 1.9.2, 1.9.3, 2.0, 2.1, JRuby (1.9 mode), and Rubinius 2.x. This library is pure Ruby and has no gem dependencies.
It should be fully compatible with any Ruby interpreter that is 1.9.x compliant.

### Example

Many more code examples can be found in the documentation for each class (linked above).
This one simple example shows some of the power of this gem.

```ruby
require 'concurrent'
require 'faker'

class EchoActor < Concurrent::Actor
  def act(*message)
    puts "#{message} handled by #{self}"
  end
end

mailbox, pool = EchoActor.pool(5)

timer_proc = proc do
  mailbox.post(Faker::Company.bs)
end

t1 = Concurrent::TimerTask.new(execution_interval: rand(5)+1, &timer_proc)
t2 = Concurrent::TimerTask.new(execution_interval: rand(5)+1, &timer_proc)

overlord = Concurrent::Supervisor.new

overlord.add_worker(t1)
overlord.add_worker(t2)
pool.each{|actor| overlord.add_worker(actor)}

overlord.run!

#=> ["mesh proactive platforms"] handled by #<EchoActor:0x007fa5ac18bdf8>
#=> ["maximize sticky portals"] handled by #<EchoActor:0x007fa5ac18bdd0>
#=> ["morph bleeding-edge markets"] handled by #<EchoActor:0x007fa5ac18bd80>
#=> ["engage clicks-and-mortar interfaces"] handled by #<EchoActor:0x007fa5ac18bd58>
#=> ["monetize transparent infrastructures"] handled by #<EchoActor:0x007fa5ac18bd30>
#=> ["morph sexy e-tailers"] handled by #<EchoActor:0x007fa5ac18bdf8>
#=> ["exploit dot-com models"] handled by #<EchoActor:0x007fa5ac18bdd0>
#=> ["incentivize virtual deliverables"] handled by #<EchoActor:0x007fa5ac18bd80>
#=> ["enhance B2B models"] handled by #<EchoActor:0x007fa5ac18bd58>
#=> ["envisioneer real-time architectures"] handled by #<EchoActor:0x007fa5ac18bd30>

overlord.stop
```

### Disclaimer

Remember, *there is no silver bullet in concurrent programming.* Concurrency is hard.
These tools will help ease the burden, but at the end of the day it is essential that you
*know what you are doing.*

* Decouple business logic from concurrency logic
* Test business logic separate from concurrency logic
* Keep the intersection of business logic and concurrency and small as possible
* Don't share mutable data unless absolutely necessary
* Protect shared data as much as possible (prefer [immutability](https://github.com/harukizaemon/hamster))
* Don't mix Ruby's [concurrency](http://ruby-doc.org/core-2.0.0/Thread.html)
  [primitives](http://www.ruby-doc.org/core-2.0.0/Mutex.html) with asynchronous concurrency libraries

## Contributors

* [Michele Della Torre](https://github.com/mighe)
* [Chris Seaton](https://github.com/chrisseaton)
* [Giuseppe Capizzi](https://github.com/gcapizzi)
* [Brian Shirai](https://github.com/brixen)
* [Chip Miller](https://github.com/chip-miller)
* [Jamie Hodge](https://github.com/jamiehodge)
* [Zander Hill](https://github.com/zph)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License and Copyright

*Concurrent Ruby* is Copyright &copy; 2013 [Jerry D'Antonio](https://twitter.com/jerrydantonio).
It is free software released under the [MIT License](http://www.opensource.org/licenses/MIT).
