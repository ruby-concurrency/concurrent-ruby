# Concurrent Ruby
[![Gem Version](https://badge.fury.io/rb/concurrent-ruby.svg)](http://badge.fury.io/rb/concurrent-ruby) [![Build Status](https://travis-ci.org/ruby-concurrency/concurrent-ruby.svg?branch=master)](https://travis-ci.org/ruby-concurrency/concurrent-ruby) [![Coverage Status](https://img.shields.io/coveralls/ruby-concurrency/concurrent-ruby/master.svg)](https://coveralls.io/r/ruby-concurrency/concurrent-ruby) [![Code Climate](https://codeclimate.com/github/ruby-concurrency/concurrent-ruby.svg)](https://codeclimate.com/github/ruby-concurrency/concurrent-ruby) [![Inline docs](http://inch-ci.org/github/ruby-concurrency/concurrent-ruby.svg)](http://inch-ci.org/github/ruby-concurrency/concurrent-ruby) [![Dependency Status](https://gemnasium.com/ruby-concurrency/concurrent-ruby.svg)](https://gemnasium.com/ruby-concurrency/concurrent-ruby) [![License](https://img.shields.io/badge/license-MIT-green.svg)](http://opensource.org/licenses/MIT) [![Gitter chat](http://img.shields.io/badge/gitter-join%20chat%20%E2%86%92-brightgreen.svg)](https://gitter.im/ruby-concurrency/concurrent-ruby)

<table>
  <tr>
    <td align="left" valign="top">
      <p>
        Modern concurrency tools for Ruby. Inspired by
        <a href="http://www.erlang.org/doc/reference_manual/processes.html">Erlang</a>,
        <a href="http://clojure.org/concurrent_programming">Clojure</a>,
        <a href="http://akka.io/">Scala</a>,
        <a href="http://www.haskell.org/haskellwiki/Applications_and_libraries/Concurrency_and_parallelism#Concurrent_Haskell">Haskell</a>,
        <a href="http://blogs.msdn.com/b/dsyme/archive/2010/02/15/async-and-parallel-design-patterns-in-f-part-3-agents.aspx">F#</a>,
        <a href="http://msdn.microsoft.com/en-us/library/vstudio/hh191443.aspx">C#</a>,
        <a href="http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/package-summary.html">Java</a>,
        and classic concurrency patterns.
      </p>
      <p>
        The design goals of this gem are:
        <ul>
          <li>Be an 'unopinionated' toolbox that provides useful utilities without debating which is better or why</li>
          <li>Remain free of external gem dependencies</li>
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
      <img src="https://raw.githubusercontent.com/wiki/ruby-concurrency/concurrent-ruby/logo/concurrent-ruby-logo-300x300.png"/>
    </td>
  </tr>
</table>

## Features & Documentation

Please see the [Concurrent Ruby Wiki](https://github.com/ruby-concurrency/concurrent-ruby/wiki)
or the [API documentation](http://ruby-concurrency.github.io/concurrent-ruby/frames.html)
for more information or join our [mailing list](http://groups.google.com/group/concurrent-ruby).

There are many concurrency abstractions in this library. These abstractions can be broadly categorized
into several general groups:

* Asynchronous concurrency abstractions including
  [Agent](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Agent.html),
  [Async](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Async.html),
  [Future](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Future.html),
  [Promise](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Promise.html),
  [ScheduledTask](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ScheduledTask.html),
  and [TimerTask](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/TimerTask.html) 
* Fast, light-weight [Actor model](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Actor.html) implementation. 
* Thread-safe variables including
  [I-Structures](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/IVar.html),
  [M-Structures](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/MVar.html),
  [thread-local variables](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ThreadLocalVar.html),
  and [software transactional memory](https://github.com/ruby-concurrency/concurrent-ruby/wiki/TVar-(STM))
* Thread synchronization classes and algorithms including
  [condition](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Condition.html),
  [countdown latch](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CountDownLatch.html),
  [dataflow](https://github.com/ruby-concurrency/concurrent-ruby/wiki/Dataflow), 
  [event](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Event.html),
  [exchanger](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Exchanger.html),
  and [timeout](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent.html#timeout-class_method)
* Java-inspired [executors](https://github.com/ruby-concurrency/concurrent-ruby/wiki/Thread%20Pools) (thread pools and more)
* [And many more](http://ruby-concurrency.github.io/concurrent-ruby/index.html)...

### Semantic Versioning

This gem adheres to the rules of [semantic versioning](http://semver.org/).

### Supported Ruby versions

MRI 1.9.3, 2.0, 2.1, JRuby (1.9 mode), and Rubinius 2.x.
Although native code is used for performance optimizations on some platforms, all functionality
is available in pure Ruby. This gem should be fully compatible with any interpreter that is
compliant with Ruby 1.9.3 or newer.

### Examples

Many more code examples can be found in the documentation for each class (linked above).

Future and ScheduledTask:

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

# ScheduledTask
task = Concurrent::ScheduledTask.execute(2){ Ticker.new.get_year_end_closing('INTC', 2013) }
task.state #=> :pending
sleep(3)   # do other stuff
task.value #=> 25.96
```

Actor:

```ruby
class Counter < Concurrent::Actor::Context
  # Include context of an actor which gives this class access to reference
  # and other information about the actor

  # use initialize as you wish
  def initialize(initial_value)
    @count = initial_value
  end

  # override on_message to define actor's behaviour
  def on_message(message)
    if Integer === message
      @count += message
    end
  end
end #

# Create new actor naming the instance 'first'.
# Return value is a reference to the actor, the actual actor is never returned.
counter = Counter.spawn(:first, 5)

# Tell a message and forget returning self.
counter.tell(1)
counter << 1
# (First counter now contains 7.)

# Send a messages asking for a result.
counter.ask(0).class
counter.ask(0).value
```

## Installing and Building

This gem includes several platform-specific optimizations. To reduce the possibility of
compilation errors, we provide pre-compiled gem packages for several platforms as well
as a pure-Ruby build. Installing the gem should be no different than installing any other
Rubygems-hosted gem. Rubygems will automatically detect your platform and install the
appropriate pre-compiled build. You should never see Rubygems attempt to compile the gem
on installation. Additionally, to ensure compatability with the largest possible number
of Ruby interpreters, the C extensions will *never* load under any Ruby other than MRI,
even when installed.

The following gem builds will be built at every release:

* concurrent-ruby-x.y.z.gem (pure Ruby)
* concurrent-ruby-x.y.z-java.gem (JRuby)
* concurrent-ruby-x.y.z-x86-linux.gem (Linux 32-bit)
* concurrent-ruby-x.y.z-x86_64-linux.gem (Linux 64-bit)
* concurrent-ruby-x.y.z-x86-mingw32.gem (Windows 32-bit)
* concurrent-ruby-x.y.z-x64-mingw32.gem (Windows 64-bit)
* concurrent-ruby-x.y.z-x86-solaris-2.11.gem (Solaris)

### Installing

```shell
gem install concurrent-ruby
```

or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby'
```

and run `bundle install` from your shell.

### Building

Because we provide pre-compiled gem builds, users should never need to build the gem manually.
The build process for this gem is completely automated using open source tools. All of
the automation components are available in the [ruby-concurrency/rake-compiler-dev-box](https://github.com/ruby-concurrency/rake-compiler-dev-box)
GitHub repository.

This gem will compile native C code under MRI and native Java code under JRuby. It is
also possible to build a pure-Ruby version. All builds have identical functionality.
The only difference is performance. Additionally, pure-Ruby classes are always available,
even when using the native optimizations. Please see the [documentation](http://ruby-concurrency.github.io/concurrent-ruby/)
for more details.

To build and package the gem using MRI or JRuby, install the necessary build dependencies and run:

```shell
bundle exec rake compile
bundle exec rake build
```

To build and package a pure-Ruby gem, on *any* platform and interpreter
(including MRI and JRuby), run:

```shell
BUILD_PURE_RUBY='true' bundle exec rake build
```

## Maintainers

* [Jerry D'Antonio](https://github.com/jdantonio)
* [Michele Della Torre](https://github.com/mighe)
* [Chris Seaton](https://github.com/chrisseaton)
* [Lucas Allan](https://github.com/lucasallan)
* [Petr Chalupa](https://github.com/pitr-ch)

### Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License and Copyright

*Concurrent Ruby* is free software released under the [MIT License](http://www.opensource.org/licenses/MIT).

The *Concurrent Ruby* [logo](https://github.com/ruby-concurrency/concurrent-ruby/wiki/Logo)
was designed by [David Jones](https://twitter.com/zombyboy).
It is Copyright &copy; 2014 [Jerry D'Antonio](https://twitter.com/jerrydantonio). All Rights Reserved.
