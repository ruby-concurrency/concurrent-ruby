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

MRI 1.9.3, 2.0, 2.1, 2.2, JRuby (1.9 mode), and Rubinius 2.x are supported.
This gem should be fully compatible with any interpreter that is compliant with Ruby 1.9.3 or newer.

## Features & Documentation

We have a roadmap guiding our work toward the [v1.0.0 release](https://github.com/ruby-concurrency/concurrent-ruby/wiki/v1.0-Roadmap).

The primary site for documentation is the automatically generated [API documentation](http://ruby-concurrency.github.io/concurrent-ruby/frames.html)

We also have a [mailing list](http://groups.google.com/group/concurrent-ruby).

This library contains a variety of concurrency abstractions at high and low levels. One of the high-level abstractions is likely to meet most common needs. 

### High-level, general-purpose asynchronous concurrency abstractions

* [Agent](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Agent.html): A single atomic value that represents an identity.
* [Async](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Async.html): A mixin module that provides simple asynchronous behavior to any standard class/object or object.
* [Future](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Future.html): An asynchronous operation that produces a value.
  * [Dataflow](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent.html#dataflow-class_method): Built on Futures, Dataflow allows you to create a task that will be scheduled when all of its data dependencies are available.
* [Promise](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Promise.html): Similar to Futures, with more features.
* [ScheduledTask](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ScheduledTask.html): Like a Future scheduled for a specific future time.
* [TimerTask](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/TimerTask.html): A Thread that periodically wakes up to perform work at regular intervals. 

### Java-inspired ThreadPools and other executors

* See [ThreadPool](http://ruby-concurrency.github.io/concurrent-ruby/file.thread_pools.html) overview, which also contains a list of other Executors available.

### Thread synchronization classes and algorithms

* [Condition](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Condition.html)
* [CountdownLatch](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CountDownLatch.html)
* [CyclicBarrier](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CyclicBarrier.html)
* [Event](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Event.html)
* [Exchanger](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Exchanger.html)
* [Semaphore](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Semaphore.html)
* [Timeout](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent.html#timeout-class_method)
* [Timer](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent.html#timer-class_method)

### Thread-safe variables

* [AtomicBoolean](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/AtomicBoolean.html)
* [AtomicFixnum](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/AtomicFixnum.html)
* [AtomicReference](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/MutexAtomic.html)
* [Delay](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Delay.html)
* [LazyRegister](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/LazyRegister.html)
* [I-Structures](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/IVar.html) (IVar)
* [M-Structures](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/MVar.html) (MVar)
* [Thread-local variables](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ThreadLocalVar.html)
* [Software transactional memory](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/TVar.html) (TVar)
* [ReadWriteLock](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ReadWriteLock.html)

### Edge features

They are available in the `concurrent-ruby-edge` companion gem, install with `gem install concurrent-ruby-edge`.

These features are under active development and may change frequently. They are expected not to
keep backward compatibility (there may also lack tests and documentation). Semantic versions will
be obeyed though. Features developed in `concurrent-ruby-edge` are expected to move to `concurrent-ruby` when final.

*   [Actor](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Actor.html):
    Implements the Actor Model, where concurrent actors exchange messages.
*   [Channel](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Channel.html):
    Communicating Sequential Processes (CSP).

## Usage

All abstractions within this gem can be loaded simply by requiring it:

```ruby
require 'concurrent'
```

To reduce the amount of code loaded at runtime, subsets of this gem can be required:

```ruby
require 'concurrent'                # everything

# groups

require 'concurrent/atomics'        # atomic and thread synchronization classes
require 'concurrent/executors'      # Thread pools and other executors
require 'concurrent/utilities'      # utility methods such as processor count and timers

# individual abstractions

require 'concurrent/agent'          # Concurrent::Agent
require 'concurrent/async'          # Concurrent::Async
require 'concurrent/atomic'         # Concurrent::Atomic (formerly the `atomic` gem)
require 'concurrent/dataflow'       # Concurrent::dataflow
require 'concurrent/delay'          # Concurrent::Delay
require 'concurrent/exchanger'      # Concurrent::Exchanger
require 'concurrent/future'         # Concurrent::Future
require 'concurrent/ivar'           # Concurrent::IVar
require 'concurrent/lazy_register'  # Concurrent::LazyRegister
require 'concurrent/mvar'           # Concurrent::MVar
require 'concurrent/promise'        # Concurrent::Promise
require 'concurrent/scheduled_task' # Concurrent::ScheduledTask
require 'concurrent/timer_task'     # Concurrent::TimerTask
require 'concurrent/tvar'           # Concurrent::TVar

# experimental - available in `concurrent-ruby-edge` companion gem

require 'concurrent/actor'          # Concurrent::Actor and supporting code
require 'concurrent/channel '       # Concurrent::Channel and supporting code
```

## Installation

```shell
gem install concurrent-ruby
```

or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby'
```

and run `bundle install` from your shell.

### C Extensions for MRI

Potential performance improvements may be achieved under MRI by installing optional C extensions.
To minimize installation errors the C extensions are available in the `concurrent-ruby-ext` extension
gem. `concurrent-ruby` and `concurrent-ruby-ext` are always released together with same version.
Simply install the extension gen too:

```ruby
gem install concurrent-ruby-ext
```

or add the following line to Gemfile:

```ruby
gem 'concurrent-ruby-ext'
```

and run `bundle install` from your shell.

In code it is only necessary to

```ruby
require 'concurrent'
```

The `concurrent-ruby` gem will automatically detect the presence of the `concurrent-ruby-ext` gem
and load the appropriate C extensions.

#### Note For gem developers

No gems should depend on `concurrent-ruby-ext`. Doing so will force C extensions on your users.
The best practice is to depend on `concurrent-ruby` and let users to decide if they want C extensions.

### Building

All published versions of this gem (core, extension, and several platform-specific packages) are compiled,
packaged, tested, and published using an open, [automated process](https://github.com/ruby-concurrency/rake-compiler-dev-box).
This process can also be used to create pre-compiled binaries of the extension gem for virtally
any platform. *Documentation is forthcoming...*

```
*MRI only*
rake build:native       # Build concurrent-ruby-ext-<version>-<platform>.gem into the pkg directory
rake compile:extension  # Compile extension

*JRuby only*
rake build              # Build JRuby-specific core gem (alias for `build:core`)
rake build:core         # Build concurrent-ruby-<version>-java.gem into the pkg directory

*All except JRuby*
rake build              # Build core and extension gems
rake build:core         # Build concurrent-ruby-<version>.gem into the pkg directory
rake build:ext          # Build concurrent-ruby-ext-<version>.gem into the pkg directory

*All*
rake clean              # Remove any temporary products
rake clobber            # Remove any generated file
rake compile            # Compile all the extensions
```

## Maintainers

* [Jerry D'Antonio](https://github.com/jdantonio)
* [Michele Della Torre](https://github.com/mighe)
* [Chris Seaton](https://github.com/chrisseaton)
* [Lucas Allan](https://github.com/lucasallan)
* [Petr Chalupa](https://github.com/pitr-ch)
* [Paweł Obrok](https://github.com/obrok)

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
