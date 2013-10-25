# Concurrent Ruby [![Build Status](https://secure.travis-ci.org/jdantonio/concurrent-ruby.png)](https://travis-ci.org/jdantonio/concurrent-ruby?branch=master) [![Coverage Status](https://coveralls.io/repos/jdantonio/concurrent-ruby/badge.png)](https://coveralls.io/r/jdantonio/concurrent-ruby) [![Dependency Status](https://gemnasium.com/jdantonio/concurrent-ruby.png)](https://gemnasium.com/jdantonio/concurrent-ruby)

Modern concurrency tools including agents, futures, promises, thread pools, supervisors, and more.
Inspired by Erlang, Clojure, Go, JavaScript, actors, and classic concurrency patterns.

If you find this gem useful you should check out my [functional-ruby](https://github.com/jdantonio/functional-ruby)
gem, too. This gem uses several of the tools in that gem.

## Introduction

The old-school "lock and synchronize" approach to concurrency is dead. The future of concurrency
is asynchronous. Send out a bunch of independent [actors](http://en.wikipedia.org/wiki/Actor_model)
to do your bidding and process the results when you are ready. Although the idea of the concurrent
actor originated in the early 1970's it has only recently started catching on. Although there is
no one "true" actor implementation (what *exactly* is "object oriented," what *exactly* is
"concurrent programming"), many modern programming languages implement variations on the actor
theme. This library implements a few of the most interesting and useful of those variations.

Remember, *there is no silver bullet in concurrent programming.* Concurrency is hard. Very hard.
These tools will help ease the burden, but at the end of the day it is essential that you
*know what you are doing.*

The project is hosted on the following sites:

* [RubyGems project page](https://rubygems.org/gems/concurrent-ruby)
* [Source code on GitHub](https://github.com/jdantonio/concurrent-ruby)
* [YARD documentation on RubyDoc.info](http://rubydoc.info/github/jdantonio/concurrent-ruby/frames)
* [Continuous integration on Travis-CI](https://travis-ci.org/jdantonio/concurrent-ruby)
* [Dependency tracking on Gemnasium](https://gemnasium.com/jdantonio/concurrent-ruby)
* [Follow me on Twitter](https://twitter.com/jerrydantonio)

### Goals

My history with high-performance, highly-concurrent programming goes back to my days with C/C++.
I have the same scars as everyone else doing that kind of work with those languages.
I'm fascinated by modern concurrency patterns like [Actors](http://en.wikipedia.org/wiki/Actor_model),
[Agents](http://doc.akka.io/docs/akka/snapshot/java/agents.html), and
[Promises](http://promises-aplus.github.io/promises-spec/). I'm equally fascinated by languages
with strong concurrency support like [Erlang](http://www.erlang.org/doc/getting_started/conc_prog.html),
[Go](http://golang.org/doc/articles/concurrency_patterns.html), and
[Clojure](http://clojure.org/concurrent_programming). My goal is to implement those patterns in Ruby.
Specifically:

* Stay true to the spirit of the languages providing inspiration
* But implement in a way that makes sense for Ruby
* Keep the semantics as idiomatic Ruby as possible
* Support features that make sense in Ruby
* Exclude features that don't make sense in Ruby
* Keep everything small
* Be as fast as reasonably possible

## Features (and Documentation)

Several features from Erlang, Go, Clojure, Java, and JavaScript have been implemented thus far:

* Clojure inspired [Agent](https://github.com/jdantonio/concurrent-ruby/blob/master/md/agent.md)
* Clojure inspired [Future](https://github.com/jdantonio/concurrent-ruby/blob/master/md/future.md)
* Scala inspired [Actor](https://github.com/jdantonio/concurrent-ruby/blob/master/md/actor.md)
* Go inspired [Goroutine](https://github.com/jdantonio/concurrent-ruby/blob/master/md/goroutine.md)
* JavaScript inspired [Promise](https://github.com/jdantonio/concurrent-ruby/blob/master/md/promise.md)
* Java inspired [Thread Pools](https://github.com/jdantonio/concurrent-ruby/blob/master/md/thread_pool.md)
* Old school [events](http://msdn.microsoft.com/en-us/library/windows/desktop/ms682655.aspx) from back in my Visual C++ days
* Repeated task execution with Java inspired [TimerTask](https://github.com/jdantonio/concurrent-ruby/blob/master/md/timer_task.md) service
* Erlang inspired [Supervisor](https://github.com/jdantonio/concurrent-ruby/blob/master/md/supervisor.md) for managing long-running threads

### Is it any good?

[Yes](http://news.ycombinator.com/item?id=3067434)

### Supported Ruby versions

MRI 1.9.2, 1.9.3, 2.0, 2.1, and JRuby (1.9 mode). This library is pure Ruby and has no gem dependencies.
It should be fully compatible with any Ruby interpreter that is 1.9.x compliant. I simply don't know enough
about Rubinius or the others to fully support them. I can promise good karma and attribution on this page
to anyone wishing to take responsibility for verifying compaitibility with any Ruby other than MRI.

### Install

```shell
gem install concurrent-ruby
```

or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby'
```

and run `bundle install` from your shell.

Once you've installed the gem you must `require` it in your project:

```ruby
require 'concurrent'
```

### Examples

For complete examples, see the specific documentation linked above. Below are a few examples to whet your appetite.

#### Goroutine (Go)

```ruby
require 'concurrent'

go('foo'){|echo| sleep(0.1); print "#{echo}\n"; sleep(0.1); print "Boom!\n" }
go('bar'){|echo| sleep(0.1); print "#{echo}\n"; sleep(0.1); print "Pow!\n" }
go('baz'){|echo| sleep(0.1); print "#{echo}\n"; sleep(0.1); print "Zap!\n" }
sleep(0.5)

#=> foo
#=> bar
#=> baz
#=> Boom!
#=> Pow!
#=> Zap!
```

#### Agent (Clojure)

```ruby
require 'concurrent'

score = Concurrent::Agent.new(10)
score.value #=> 10

score << proc{|current| current + 100 }
sleep(0.1)
score.value #=> 110

score << proc{|current| current * 2 }
sleep(0.1)
score.value #=> 220

score << proc{|current| current - 50 }
sleep(0.1)
score.value #=> 170
```

#### Future (Clojure)

```ruby
require 'concurrent'

count = Concurrent::Future.new{ sleep(1); 10 }
count.state #=> :pending
# do stuff...
count.value #=> 10 (after blocking)
```

#### Promise (JavaScript)

```ruby
require 'concurrent'

p = Concurrent::Promise.new("Jerry", "D'Antonio"){|a, b| "#{a} #{b}" }.
    then{|result| "Hello #{result}." }.
    rescue(StandardError){|ex| puts "Boom!" }.
    then{|result| "#{result} Would you like to play a game?"}
sleep(1)
p.value #=> "Hello Jerry D'Antonio. Would you like to play a game?" 
```

#### Thread Pools (Java)

```ruby
require 'concurrent'

pool = Concurrent::FixedThreadPool.new(2)
pool.size #=> 2

pool.post{ sleep(0.5); print "Boom!\n" }
pool.size #=> 2
pool.post{ sleep(0.5); print "Pow!\n" }
pool.size #=> 2
pool.post{ sleep(0.5); print "Zap!\n" }
pool.size #=> 2

sleep(1)

#=> Boom!
#=> Pow!
#=> Zap!

pool = Concurrent::CachedThreadPool.new
pool.size #=> 0

pool << proc{ sleep(0.5); print "Boom!\n" }
pool.size #=> 1
pool << proc{ sleep(0.5); print "Pow!\n" }
pool.size #=> 2
pool << proc{ sleep(0.5); print "Zap!\n" }
pool.size #=> 3

sleep(1)

#=> Boom!
#=> Pow!
#=> Zap!
```

#### TimerTask (Java)

```ruby
require 'concurrent'

ec = Concurrent::TimerTask.run{ puts 'Boom!' }

ec.execution_interval #=> 60 == Concurrent::TimerTask::EXECUTION_INTERVAL
ec.timeout_interval   #=> 30 == Concurrent::TimerTask::TIMEOUT_INTERVAL
ec.status             #=> "sleep"

# wait 60 seconds...
#=> 'Boom!'

ec.kill #=> true
```

#### Actor (Scala)

```ruby
class FinanceActor < Concurrent::Actor
  def act(query)
    finance = Finance.new(query)
    print "[#{Time.now}] RECEIVED '#{query}' to #{self} returned #{finance.update.suggested_symbols}\n\n"
  end
end

financial, pool = FinanceActor.pool(5)

pool << 'YAHOO'
pool << 'Micosoft'
pool << 'google'
```

#### Supervisor (Erlang)

```ruby
pong = Pong.new
ping = Ping.new(10000, pong)
pong.ping = ping

task = Concurrent::TimerTask.new{ print "Boom!\n" }

boss = Concurrent::Supervisor.new
boss.add_worker(ping)
boss.add_worker(pong)
boss.add_worker(task)

boss.run!

ping << :pong
```

## Todo

* DelayedTask (aka ScheduledTask)
* More methods from Scala's Actor
* [Task Parallel Library (TPL)](http://msdn.microsoft.com/en-us/library/dd460717.aspx)
  * [Data Parallelism](http://msdn.microsoft.com/en-us/library/dd537608.aspx)
  * [Task Parallelism](http://msdn.microsoft.com/en-us/library/dd537609.aspx)
* More Erlang goodness
  * gen_server
  * gen_event
  * gen_fsm

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

*Concurrent Ruby* is Copyright &copy; 2013 [Jerry D'Antonio](https://twitter.com/jerrydantonio).
It is free software and may be redistributed under the terms specified in the LICENSE file.

## License

Released under the MIT license.

http://www.opensource.org/licenses/mit-license.php  

> Permission is hereby granted, free of charge, to any person obtaining a copy  
> of this software and associated documentation files (the "Software"), to deal  
> in the Software without restriction, including without limitation the rights  
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
> copies of the Software, and to permit persons to whom the Software is  
> furnished to do so, subject to the following conditions:  
> 
> The above copyright notice and this permission notice shall be included in  
> all copies or substantial portions of the Software.  
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN  
> THE SOFTWARE.  
