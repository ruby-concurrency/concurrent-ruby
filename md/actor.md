# Actor

Actor-based concurrency is all the rage in some circles. Originally described in
1973, the actor model is a paradigm for creating asynchronous, concurrent objects
that is becoming increasingly popular. Much has changed since actors were first
written about four decades ago, which has led to a serious fragmentation within
the actor community. There is *no* universally accepted, strict definition of
"actor" and actor implementations differ widely between languages and libraries.

A good definition of "actor" is:

> An independent, concurrent, single-purpose, computational entity that
> communicates exclusively via message passing.

The `Concurrent::Actor` class in this library is based solely on the
[Actor](http://www.scala-lang.org/api/current/index.html#scala.actors.Actor) task
defined in the Scala standard library. It does not implement all the features of
Scala's `Actor` but its behavior for what *has* been implemented is nearly identical.
The excluded features mostly deal with Scala's message semantics, strong typing,
and other characteristics of Scala that don't really apply to Ruby.

Unlike most of the abstractions in this library, `Actor` takes an *object-oriented*
approach to asynchronous concurrency, rather than a *functional programming*
approach.

## Definition

Actors are defined by subclassing the `Concurrent::Actor` class and overriding the
`#act` method. The `#act` method can have any signature/arity but

```ruby
def act(*args)
```

is the most flexible and least error-prone signature. The `#act` method is called in
response to a message being post to the `Actor` instance (see *Behavior* below).

## Behavior

The `Concurrent::Actor` class includes the `Concurrent::Runnable` module. This provides
an `Actor` instance with the necessary methods for running and graceful stopping.
This also means that an `Actor` can be managed by a `Concurrent::Supervisor` for
fault tolerance.

### Message Passing

Messages from any thread can be sent (aka "post") to an `Actor` using several methods.
When a message is post all arguments are gathered together and queued for processing.
Messages are processed in the order they are received, one at a time, on a dedicated
thread. When a message is processed the subclass `#act` method is called and the return
value (or raised exception) is handled by the superclass based on the rules of the method
used to post the message.

All message posting methods are compatible with observation (see below).

Message processing within the `#act` method is not limited in any way, but care should
be taken to behave in a thread-safe, concurrency-friendly manner. A common practice is for
one `Actor` to send messages to another `Actor` though this is hardly the only approach.

Messages post to an `Actor` that is not running will be rejected.

#### Fire and Forget

The primary method of posting a message to an `Actor` is the simple `#post` method.
When this method is called the message is queued for processing. The method returns
false if it cannot be queued (the `Actor` is not running) otherwise it returns the
size of the queue (after queueing the new message). The caller thread has no way
to know the result of the message processing. When the `#post` method is used the
only way to act upon the result of the message processing is via observation
(see below).

#### Post with an Obligation

A common theme in modern asynchronous concurrency is for operations to return a
"future" (or "promise"). In this context a "future" is not an instance of the
`Concurrent::Future` class, but it is an object with similar behavior. Within
this library "future" behavior is genericized by the `Concurrent::Obligation`
mixin module (shared by `Future`, `Promise`, and others).

To post a message that returns a `Obligation` use the `#post?` method. If the message
cannot be queued the method will return `nil`. Otherwise an object implementing
`Obligation` will returned. The `Obligation` has the exteced states (`:pending`,
`:fulfilled`, and `:rejected`), the expected state-named predicate methods,
plus `#value` and `#reason`. These methods all behave identically to `Concurrent::Future`.

#### Post with Timeout

Threads posting messages to an `Actor` should generally not block. Blocking to wait
for an `Actor` to process a specific message defeats the purpose of asynchronous
concurrency. The `#post!` method is provided when the caller absolutely must block.
The first argument to `#post!` is a number of seconds to block while waiting for the
operation to complete. All subsequent arguments constitute the message and are
queued for delivery to the `#act` method. If the queued operation completes within
the timeout period the `#post!` method returns the result of the operation.

Unlike most methods in this library, the `#post!` method does not suppress exceptions.
Because the `#post!` method return value represents the result of message processing
the return value cannot effectively communicate failure. Instead, exceptions are used.
Calls to the `#post!` method should generally be wrapped in `rescue` guards. The
following exceptions may be raised by the `#post!` method:

* `Concurrent::Runnable::LifecycleError` will be raised if the message cannot be
  queued, such as when the `Actor` is not running.
* `Concurrent::TimeoutError` will be raised if the message is not processed within
  the designated timeout period
* Any exception raised during message processing will be re-raised after all
  post-processing operations (such as observer callbacks) have completed

When the `#post!` method results in a timeout the `Actor` will attempt to cancel
message processing, but cancellation is not guaranteed. If message processing has
not begun the cancellation will normally occur. If message processing is in-progress
when `#post!` reaches timeout then processing will be allowed to complete. Code that
uses the `#post!` method must therefore not assume that a timeout means that message
processing did not occur.

#### Implicit Forward/Reply

A common idiom is for an `Actor` to send messages to another `Actor`. This creates
a "data flow" style of design not dissimilar to Unix-style pipe commands. Less common,
but still frequent, is for an `Actor` to send the result of message processing back
to the `Actor` that sent the message. In Scala this is easy to do. The underlying
message passing system implicitly communicates to the receiver the address of the
sender. Therefore, Scala actors can easily reply to the sender. Ruby has no similar
message passing subsystem to implicit knowledge of the sender is not possible. This
`Actor` implementation provides a `#forward` method that encapsulates both
aforementioned idioms. The first argument to the `#forward` method is a reference
to another `Actor` to which the receiving `Actor` should forward the result of
the processed messages. All subsequent arguments constitute the message and are
queued for delivery to the `#act` method.

Upon successful message processing the `Actor` superclass will automatically
forward the result to the receiver provided when `#forward` was called. If an
exception is raised no forwarding occurs.

### Error Handling

Because `Actor` mixes in the `Concurrent::Runnable` module subclasses have access to
the `#on_error` method and can override it to implement custom error handling. The
`Actor` base class does not use `#on_error` so as to avoid conflit with subclasses
which override it. Generally speaking, `#on_error` should not be used. The `Actor`
base class provides concictent, reliable, and robust error handling already, and
error handling specifics are tied to the message posting method. Incorrect behavior
in an `#on_error` override can lead to inconsistent `Actor` behavior that may lead
to confusion and difficult debugging.

### Observation

The `Actor` superclass mixes in the Ruby standard library
[Observable](http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html)
module to provide consistent callbacks upon message processing completion. The normal
`Observable` methods, including `#add_observer` behave normally. Once an observer
is added to an `Actor` it will be notified of all messages processed *after*
addition. Notification will *not* occur for any messages that have already been
processed.

Observers will be notified regardless of whether the message processing is successful
or not. The `#update` method of the observer will receive four arguments. The
appropriate method signature is:

```ruby
def update(time, message, result, reason)
```

These four arguments represent:

* The time that message processing was completed
* An array containing all elements of the original message, in order
* The result of the call to `#act` (will be `nil` if an exception was raised)
* Any exception raised by `#act` (or `nil` if message processing was successful)

### Actor Pools

Every `Actor` instance operates on its own thread. When one thread isn't enough capacity
to manage all the messages being sent to an `Actor` a *pool* can be used instead. A pool
is a collection of `Actor` instances, all of the same type, that shate a message queue.
Messages from other threads are all sent to a single queue against which all `Actor`s
load balance.

## Additional Reading

* [API documentation](http://www.scala-lang.org/api/current/index.html#scala.actors.Actor)
  for the original (now deprecated) Scala Actor
* [Scala Actors: A Short Tutorial](http://www.scala-lang.org/old/node/242)
* [Scala Actors 101](http://java.dzone.com/articles/scala-threadless-concurrent)

## Examples

Two `Actor`s playing a back and forth game of Ping Pong, adapted from the Scala example
[here](http://www.scala-lang.org/old/node/242):

```ruby
class Ping < Concurrent::Actor

  def initialize(count, pong)
    super()
    @pong = pong
    @remaining = count
  end
  
  def act(msg)

    if msg == :pong
      print "Ping: pong\n" if @remaining % 1000 == 0
      @pong.post(:ping)

      if @remaining > 0
        @pong << :ping
        @remaining -= 1
      else
        print "Ping :stop\n"
        @pong << :stop
        self.stop
      end
    end
  end
end

class Pong < Concurrent::Actor

  attr_writer :ping

  def initialize
    super()
    @count = 0
  end

  def act(msg)

    if msg == :ping
      print "Pong: ping\n" if @count % 1000 == 0
      @ping << :pong
      @count += 1

    elsif msg == :stop
      print "Pong :stop\n"
      self.stop
    end
  end
end

pong = Pong.new
ping = Ping.new(10000, pong)
pong.ping = ping

t1 = ping.run!
t2 = pong.run!
sleep(0.1)

ping << :pong
```

A pool of `Actor`s and a `Supervisor`

```ruby
QUERIES = %w[YAHOO Microsoft google]

class FinanceActor < Concurrent::Actor
  def act(query)
    finance = Finance.new(query)
    print "[#{Time.now}] RECEIVED '#{query}' to #{self} returned #{finance.update.suggested_symbols}\n\n"
  end
end

financial, pool = FinanceActor.pool(5)

overlord = Concurrent::Supervisor.new
pool.each{|actor| overlord.add_worker(actor)}

overlord.run! 

financial.post('YAHOO')

#>> [2013-10-18 09:35:28 -0400] SENT 'YAHOO' from main to worker pool
#>> [2013-10-18 09:35:28 -0400] RECEIVED 'YAHOO' to #<FinanceActor:0x0000010331af70>...
```

The `#post` method simply sends a message to an actor and returns. It's a
fire-and-forget interaction.

```ruby
class EchoActor < Concurrent::Actor
  def act(*message)
    p message
  end
end

echo = EchoActor.new
echo.run!

echo.post("Don't panic") #=> true
#=> ["Don't panic"]

echo.post(1, 2, 3, 4, 5) #=> true
#=> [1, 2, 3, 4, 5]

echo << "There's a frood who really knows where his towel is." #=> #<EchoActor:0x007fc8012b8448...
#=> ["There's a frood who really knows where his towel is."]
```

The `#post?` method returns an `Obligation` (same API as `Future`) which can be queried
for value/reason on fulfillment/rejection.

```ruby
class EverythingActor < Concurrent::Actor
  def act(message)
    sleep(5)
    return 42
  end
end

life = EverythingActor.new
life.run!
sleep(0.1)

universe = life.post?('What do you get when you multiply six by nine?')
universe.pending? #=> true

# wait for it...

universe.fulfilled? #=> true
universe.value      #=> 42
```

The `#post!` method is a blocking call. It takes a number of seconds to wait as the
first parameter and any number of additional parameters as the message. If the message
is processed within the given number of seconds the call returns the result of the
operation. If message processing raises an exception the exception is raised again
by the `#post!` method. If the call to `#post!` times out a `Concurrent::Timeout`
exception is raised.

```ruby
life = EverythingActor.new
life.run!
sleep(0.1)

life.post!(1, 'Mostly harmless.')

# wait for it...
#=> Concurrent::TimeoutError: Concurrent::TimeoutError
```

And, of course, the `Actor` class mixes in Ruby's `Observable`.

```ruby
class ActorObserver
  def update(time, message, result, ex)
    if result
      print "(#{time}) Message #{message} returned #{result}\n"
    elsif ex.is_a?(Concurrent::TimeoutError)
      print "(#{time}) Message #{message} timed out\n"
    else
      print "(#{time}) Message #{message} failed with error #{ex}\n"
    end
  end
end

class SimpleActor < Concurrent::Actor
  def act(*message)
    message
  end
end

actor = SimpleActor.new
actor.add_observer(ActorObserver.new)
actor.run!

actor.post(1)
#=> (2013-11-07 18:35:33 -0500) Message [1] returned [1]

actor.post(1,2,3)
#=> (2013-11-07 18:35:54 -0500) Message [1, 2, 3] returned [1, 2, 3]

actor.post('The Nightman Cometh')
#=> (2013-11-07 18:36:11 -0500) Message ["The Nightman Cometh"] returned ["The Nightman Cometh"]
```

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
