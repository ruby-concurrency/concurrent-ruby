# Concurrent Ruby
[![Gem Version](https://badge.fury.io/rb/concurrent-ruby.png)](http://badge.fury.io/rb/concurrent-ruby) [![Build Status](https://secure.travis-ci.org/jdantonio/concurrent-ruby.png)](https://travis-ci.org/jdantonio/concurrent-ruby?branch=master) [![Coverage Status](https://coveralls.io/repos/jdantonio/concurrent-ruby/badge.png)](https://coveralls.io/r/jdantonio/concurrent-ruby) [![Code Climate](https://codeclimate.com/github/jdantonio/concurrent-ruby.png)](https://codeclimate.com/github/jdantonio/concurrent-ruby) [![Inline docs](http://inch-pages.github.io/github/jdantonio/concurrent-ruby.png)](http://inch-pages.github.io/github/jdantonio/concurrent-ruby) [![Dependency Status](https://gemnasium.com/jdantonio/concurrent-ruby.png)](https://gemnasium.com/jdantonio/concurrent-ruby)

<table>
<tr>
<td align="left" valign="top">
<p>
Modern concurrency tools for Ruby. Inspired by
<a href="http://www.erlang.org/doc/reference_manual/processes.html">Erlang</a>,
<a href="http://clojure.org/concurrent_programming">Clojure</a>,
<a href="http://www.scala-lang.org/api/current/index.html#scala.actors.Actor">Scala</a>,
<a href="http://www.haskell.org/haskellwiki/Applications_and_libraries/Concurrency_and_parallelism#Concurrent_Haskell">Haskell</a>,
<a href="http://blogs.msdn.com/b/dsyme/archive/2010/02/15/async-and-parallel-design-patterns-in-f-part-3-agents.aspx">F#</a>,
<a href="http://msdn.microsoft.com/en-us/library/vstudio/hh191443.aspx">C#</a>,
<a href="http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/package-summary.html">Java</a>,
and classic concurrency patterns.
</p>
<p>
The design goals of this gem are:
<ul>
<li>Stay true to the spirit of the languages providing inspiration</li>
<li>But implement in a way that makes sense for Ruby</li>
<li>Keep the semantics as idiomatic Ruby as possible</li>
<li>Support features that make sense in Ruby</li>
<li>Exclude features that don't make sense in Ruby</li>
<li>Be small, lean, and loosely coupled</li>
</ul>
</p>
</td>
<td align="right" valign="top">
<img src="https://raw.githubusercontent.com/wiki/jdantonio/concurrent-ruby/logo/concurrent-ruby-logo-300x300.png"/>
</td>
</tr>
</table>

### Install

```shell
gem install concurrent-ruby
```
or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby'
```
and run `bundle install` from your shell.

*NOTE: There is an old gem from 2007 called "concurrent" that does not appear to be under active development. That isn't us. Please do not run* `gem install concurrent`*. It is not the droid you are looking for.*

## Features & Documentation

Please see the [Concurrent Ruby Wiki](https://github.com/jdantonio/concurrent-ruby/wiki)
or the [API documentation](http://rubydoc.info/github/jdantonio/concurrent-ruby/master/frames)
for more information or join our [mailing list](http://groups.google.com/group/concurrent-ruby).

There are many concurrency abstractions in this library. These abstractions can be broadly categorized
into several general groups:

* Asynchronous concurrency abstractions including
  [Async](https://github.com/jdantonio/concurrent-ruby/wiki/Async),
  [Agent](https://github.com/jdantonio/concurrent-ruby/wiki/Agent),
  [Future](https://github.com/jdantonio/concurrent-ruby/wiki/Future),
  [Promise](https://github.com/jdantonio/concurrent-ruby/wiki/Promise),
  [ScheduledTask](https://github.com/jdantonio/concurrent-ruby/wiki/ScheduledTask),
  and [TimerTask](https://github.com/jdantonio/concurrent-ruby/wiki/TimerTask) 
* Erlang-inspired [Supervisor](https://github.com/jdantonio/concurrent-ruby/wiki/Supervisor) and other lifecycle classes/mixins
  for managing long-running threads
* Thread-safe variables including [M-Structures](https://github.com/jdantonio/concurrent-ruby/wiki/MVar-(M-Structure)),
  [I-Structures](https://github.com/jdantonio/concurrent-ruby/wiki/IVar-(I-Structure)),
  [thread-local variables](https://github.com/jdantonio/concurrent-ruby/wiki/ThreadLocalVar),
  atomic counters, and [software transactional memory](https://github.com/jdantonio/concurrent-ruby/wiki/TVar-(STM))
* Thread synchronization classes and algorithms including [dataflow](https://github.com/jdantonio/concurrent-ruby/wiki/Dataflow), 
  timeout, condition, countdown latch, dependency counter, and event
* Java-inspired [thread pools](https://github.com/jdantonio/concurrent-ruby/wiki/Thread%20Pools)
* And many more...

### Semantic Versioning

This gem adheres to the rules of [semantic versioning](http://semver.org/).

### Supported Ruby versions

MRI 1.9.3, 2.0, 2.1, JRuby (1.9 mode), and Rubinius 2.x.
This library is pure Ruby and has no gem dependencies.
It should be fully compatible with any interpreter that is compliant with Ruby 1.9.3 or newer.

### Examples

Many more code examples can be found in the documentation for each class (linked above).
This one simple example shows some of the power of this gem.

```ruby
require 'concurrent'
require 'thread'   # for Queue
require 'open-uri' # for open(uri)

class Ticker
  def get_year_end_closing(symbol, year)
    uri = "http://ichart.finance.yahoo.com/table.csv?s=#{symbol}&a=11&b=01&c=#{year}&d=11&e=31&f=#{year}&g=m"
    data = open(uri) {|f| f.collect{|line| line.strip } }
    data[1].split(',')[4].to_f
  end
end

# Future
price = Concurrent::Future.execute{ Ticker.new.get_year_end_closing('TWTR', 2013) }
price.state #=> :pending
sleep(1)    # do other stuff
price.value #=> 63.65
price.state #=> :fulfilled

# Promise
prices = Concurrent::Promise.new{ puts Ticker.new.get_year_end_closing('AAPL', 2013) }.
           then{ puts Ticker.new.get_year_end_closing('MSFT', 2013) }.
           then{ puts Ticker.new.get_year_end_closing('GOOG', 2013) }.
           then{ puts Ticker.new.get_year_end_closing('AMZN', 2013) }.execute
prices.state #=> :pending
sleep(1)     # do other stuff
#=> 561.02
#=> 37.41
#=> 1120.71
#=> 398.79

# ScheduledTask
task = Concurrent::ScheduledTask.execute(2){ Ticker.new.get_year_end_closing('INTC', 2013) }
task.state #=> :pending
sleep(3)   # do other stuff
task.value #=> 25.96

# Async
ticker = Ticker.new
ticker.extend(Concurrent::Async)
hpq = ticker.async.get_year_end_closing('HPQ', 2013)
ibm = ticker.await.get_year_end_closing('IBM', 2013)
hpq.value #=> 27.98
ibm.value #=> 187.57
```

## Contributors

* [Jerry D'Antonio](https://github.com/jdantonio)
* [Michele Della Torre](https://github.com/mighe)
* [Chris Seaton](https://github.com/chrisseaton)
* [Lucas Allan](https://github.com/lucasallan)
* [Ravil Bayramgalin](https://github.com/brainopia)
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

*Concurrent Ruby* is free software released under the [MIT License](http://www.opensource.org/licenses/MIT).

The *Concurrent Ruby* [logo](https://github.com/jdantonio/concurrent-ruby/wiki/Logo)
was designed by [David Jones](https://twitter.com/zombyboy).
It is Copyright &copy; 2014 [Jerry D'Antonio](https://twitter.com/jerrydantonio). All Rights Reserved.
