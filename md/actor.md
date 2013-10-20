# All the world's a stage

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
Scala's `Actor` but its behavior for what *has* been implemented is nearly identical

## Definition

Actors are defined by subclassing the `Concurrent::Actor` class and overriding the
`#act` method. The `#act` method can have any signature/arity but

> def act(*args, &block)

is the most flexible and least error-prone signature. The `#act` method is called in
response to a message being `#post` to the `Actor` instance (see *Behavior* below).

## Behavior

The `Concurrent::Actor` class includes the `Concurrent::Runnable` module. This provides
an `Actor` instance with the necessary methods for running and graceful stopping.
This also means that an `Actor` can be managed by a `Concurrent::Supervisor` for
fault tolerance.

Messages from any thread can be sent to an `Actor` using either the `#post` method. Calling
this method causes all arguments and a block (if given) to be passed to the subclass `#act`
method. Messages are processed one at a time in the order received. Each `Actor` subclass
must detemine how it will interact with the rest of the system. A common practice is for
one `Actor` to send messages to another `Actor` though this is hardly the only approach.

## Pools

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
[here](http://www.somewhere.com/find/the/blog/post):

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

pool.post('YAHOO')

#>> [2013-10-18 09:35:28 -0400] SENT 'YAHOO' from main to worker pool
#>> [2013-10-18 09:35:28 -0400] RECEIVED 'YAHOO' to #<FinanceActor:0x0000010331af70>...
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
