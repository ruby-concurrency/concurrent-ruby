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
      <img src="https://raw.githubusercontent.com/ruby-concurrency/concurrent-ruby/master/doc/logo/concurrent-ruby-logo-300x300.png"/>
    </td>
  </tr>
</table>

### Supported Ruby versions

MRI 1.9.3, 2.0, 2.1, JRuby (1.9 mode), and Rubinius 2.x are supported.
This gem should be fully compatible with any interpreter that is compliant with Ruby 1.9.3 or newer.

## Features & Documentation

We have a roadmap guiding our work toward the [v1.0.0 release](https://github.com/ruby-concurrency/concurrent-ruby/wiki/v1.0-Roadmap).

The primary site for documentation is the automatically generated [API documentation](http://ruby-concurrency.github.io/concurrent-ruby/frames.html)

We also have a [mailing list](http://groups.google.com/group/concurrent-ruby).

This library contains a variety of concurrency abstractions at high and low levels. One of the high-level abstractions is likely to meet most common needs. 

### High-level, general-purpose asynchronous concurrency abstractions

* [Actor](./doc/actor/main.md): Implements the Actor Model, where concurrent actors exchange messages. 
* [Agent](./doc/agent.md): A single atomic value that represents an identity.
* [Async](./doc/async.md): A mixin module that provides simple asynchronous behavior to any standard class/object or object.
* [Future](./doc/future.md): An asynchronous operation that produces a value.
  * [Dataflow](./doc/dataflow.md): Built on Futures, Dataflow allows you to create a task that will be scheduled when all of its data dependencies are available.
* [Promise](./doc/promise.md): Similar to Futures, with more features. 
* [ScheduledTask](./doc/scheduled_task.md): Like a Future scheduled for a specific future time. 
* [TimerTask](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/TimerTask.html): A Thread that periodically wakes up to perform work at regular intervals. 


### Java-inspired ThreadPools and other executors

* See [ThreadPool](./doc/thread_pools.md) overview, which also contains a list of other Executors available.

### Thread-safe Observers

* [Concurrent::Observable](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Observable.html) mixin module
* [CopyOnNotifyObserverSet](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CopyOnNotifyObserverSet.html)
* [CopyOnWriteObserverSet](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CopyOnWriteObserverSet.html)

### Thread synchronization classes and algorithms
Lower-level abstractions mainly used as building blocks. 

* [condition](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Condition.html)
* [countdown latch](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CountDownLatch.html)
* [cyclic barrier](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CyclicBarrier.html)
* [event](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Event.html)
* [exchanger](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Exchanger.html)
* [timeout](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent.html#timeout-class_method)
* [timer](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent.html#timer-class_method)

### Thread-safe variables
Lower-level abstractions mainly used as building blocks. 

* [AtomicBoolean](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/AtomicBoolean.html)
* [AtomicFixnum](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/AtomicFixnum.html)
* AtomicReference (no docs currently available, check source)
* [I-Structures](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/IVar.html) (IVar)
* [M-Structures](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/MVar.html) (MVar)
* [thread-local variables](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ThreadLocalVar.html)
* [software transactional memory](./doc/tvar.md) (TVar)

## Installing

```shell
gem install concurrent-ruby
```

or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby'
```

and run `bundle install` from your shell.

### Installing Optional C Extensions (MRI)

For improved performance on MRI a compantion gem with called `concurrent-ruby-ext` is provided. When the
extensions are installed `concurrent-ruby` will detect their presence and automatically load them.

```shell
gem install concurrent-ruby-ext
```

or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby'-ext
```

and run `bundle install` from your shell.

In your code make sure you require the extension gem **before** you require the core gem:

```ruby
require 'concurrent_ext'
require 'concurrent'
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
