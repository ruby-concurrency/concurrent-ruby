# We're Going to Need a Bigger Boat

Thread pools are neither a new idea nor an implementation of the actor pattern. Nevertheless, thread
pools are still an extremely relevant concurrency tool. Every time a thread is created then
subsequently destroyed there is overhead. Creating a pool of reusable worker threads then repeatedly'
dipping into the pool can have huge performace benefits for a long-running application like a service.
Ruby's blocks provide an excellent mechanism for passing a generic work request to a thread, making
Ruby an excellent candidate language for thread pools.

The inspiration for thread pools in this library is Java's `java.util.concurrent` implementation of
[thread pools](java.util.concurrent). The `java.util.concurrent` library is a well-designed, stable,
scalable, and battle-tested concurrency library. It provides three different implementations of thread
pools. One of those implementations is simply a special case of the first and doesn't offer much
advantage in Ruby, so only the first two (`FixedThreadPool` and `CachedThreadPool`) are implemented here.

Thread pools share common `behavior` defined by `:thread_pool`. The most imortant method is `post`
(aliased with the left-shift operator `<<`). The `post` method sends a block to the pool for future
processing.

A running thread pool can be shutdown in an orderly or disruptive manner. Once a thread pool has been
shutdown in cannot be started again. The `shutdown` method can be used to initiate an orderly shutdown
of the thread pool. All new `post` calls will reject the given block and immediately return `false`.
Threads in the pool will continue to process all in-progress work and will process all tasks still in
the queue. The `kill` method can be used to immediately shutdown the pool. All new `post` calls will
reject the given block and immediately return `false`. Ruby's `Thread.kill` will be called on all threads
in the pool, aborting all in-progress work. Tasks in the queue will be discarded.

A client thread can choose to block and wait for pool shutdown to complete. This is useful when shutting
down an application and ensuring the app doesn't exit before pool processing is complete. The method
`wait_for_termination` will block for a maximum of the given number of seconds then return `true` if
shutdown completed successfully or `false`. When the timeout value is `nil` the call will block
indefinitely. Calling `wait_for_termination` on a stopped thread pool will immediately return `true`.

Predicate methods are provided to describe the current state of the thread pool. Provided methods are
`running?`, `shutdown?`, and `killed?`. The `shutdown` method will return true regardless of whether
the pool was shutdown wil `shutdown` or `kill`.

## FixedThreadPool

From the docs:

> Creates a thread pool that reuses a fixed number of threads operating off a shared unbounded queue.
> At any point, at most `nThreads` threads will be active processing tasks. If additional tasks are submitted
> when all threads are active, they will wait in the queue until a thread is available. If any thread terminates
> due to a failure during execution prior to shutdown, a new one will take its place if needed to execute
> subsequent tasks. The threads in the pool will exist until it is explicitly `shutdown`.

### Examples

```ruby
require 'concurrent'

pool = Concurrent::FixedThreadPool.new(5)

pool.size     #=> 5
pool.running? #=> true
pool.status   #=> ["sleep", "sleep", "sleep", "sleep", "sleep"]

pool.post(1,2,3){|*args| sleep(10) }
pool << proc{ sleep(10) }
pool.size     #=> 5

sleep(11)
pool.status   #=> ["sleep", "sleep", "sleep", "sleep", "sleep"]

pool.shutdown #=> :shuttingdown
pool.status   #=> []
pool.wait_for_termination

pool.size      #=> 0
pool.status    #=> []
pool.shutdown? #=> true
```

## CachedThreadPool

From the docs:

> Creates a thread pool that creates new threads as needed, but will reuse previously constructed threads when
> they are available. These pools will typically improve the performance of programs that execute many short-lived
> asynchronous tasks. Calls to [`post`] will reuse previously constructed threads if available. If no existing
> thread is available, a new thread will be created and added to the pool. Threads that have not been used for
> sixty seconds are terminated and removed from the cache. Thus, a pool that remains idle for long enough will
> not consume any resources. Note that pools with similar properties but different details (for example,
> timeout parameters) may be created using [`CachedThreadPool`] constructors.

### Examples

```ruby
require 'concurrent'

pool = Concurrent::CachedThreadPool.new

pool.size     #=> 0
pool.running? #=> true
pool.status   #=> []

pool.post(1,2,3){|*args| sleep(10) }
pool << proc{ sleep(10) }
pool.size     #=> 2
pool.status   #=> [[:working, nil, "sleep"], [:working, nil, "sleep"]]

sleep(11)
pool.status   #=> [[:idle, 23, "sleep"], [:idle, 23, "sleep"]]

sleep(60)
pool.size     #=> 0
pool.status   #=> []

pool.shutdown #=> :shuttingdown
pool.status   #=> []
pool.wait_for_termination

pool.size      #=> 0
pool.status    #=> []
pool.shutdown? #=> true
```

## Global Thread Pool

For efficiency, of the aforementioned concurrency methods (agents, futures, promises, and
goroutines) run against a global thread pool. This pool can be directly accessed through the
`$GLOBAL_THREAD_POOL` global variable. Generally, this pool should not be directly accessed.
Use the other concurrency features instead.

By default the global thread pool is a `NullThreadPool`. This isn't a real thread pool at all.
It's simply a proxy for creating new threads on every post to the pool. I couldn't decide which
of the other threads pools and what configuration would be the most universally appropriate so
I punted. If you understand thread pools then you know enough to make your own choice. That's
why the global thread pool can be changed.

### Changing the Global Thread Pool

It is possible to change the global thread pool. Simply assign a new pool to the `$GLOBAL_THREAD_POOL`
variable:

```ruby
$GLOBAL_THREAD_POOL = Concurrent::FixedThreadPool.new(10)
```

Ideally this should be done at application startup, before any concurrency functions are called.
If the circumstances warrant the global thread pool can be changed at runtime. Just make sure to
shutdown the old global thread pool so that no tasks are lost:

```ruby
$GLOBAL_THREAD_POOL = Concurrent::FixedThreadPool.new(10)

# do stuff...

old_global_pool = $GLOBAL_THREAD_POOL
$GLOBAL_THREAD_POOL = Concurrent::FixedThreadPool.new(10)
old_global_pool.shutdown
```

### NullThreadPool

If for some reason an appliction would be better served by *not* having a global thread pool, the
`NullThreadPool` is provided. The `NullThreadPool` is compatible with the global thread pool but
it is not an actual thread pool. Instead it spawns a new thread on every call to the `post` method.

### EventMachine

The [EventMachine](http://rubyeventmachine.com/) library (source [online](https://github.com/eventmachine/eventmachine))
is an awesome library for creating evented applications. EventMachine provides its own thread pool
and the authors recommend using their pool rather than using Ruby's `Thread`. No sweat,
`concurrent-ruby` is fully compatible with EventMachine. Simple require `eventmachine`
*before* requiring `concurrent-ruby` then replace the global thread pool with an instance
of `EventMachineDeferProxy`:

```ruby
require 'eventmachine' # do this FIRST
require 'concurrent'

$GLOBAL_THREAD_POOL = EventMachineDeferProxy.new
```

## Per-class Thread Pools

Many of the classes in this library use the global thread pool rather than creating new threads.
Classes such as `Agent`, `Defer`, and others follow this pattern. There may be cases where a
program would be better suited for one or more of these classes used a different thread pool.
All classes that use the global thread pool support a class-level `thread_pool` attribute accessor.
This property defaults to the global thread pool but can be changed at any time. Once changed, all
new instances of that class will use the new thread pool.

```ruby
Concurrent::Agent.thread_pool == $GLOBAL_THREAD_POOL #=> true

$GLOBAL_THREAD_POOL = Concurrent::FixedThreadPool.new(10) #=> #<Concurrent::FixedThreadPool:0x007fe31130f1f0 ...

Concurrent::Agent.thread_pool == $GLOBAL_THREAD_POOL #=> false

Concurrent::Defer.thread_pool = Concurrent::CachedThreadPool.new #=> #<Concurrent::CachedThreadPool:0x007fef1c6b6b48 ...
Concurrent::Defer.thread_pool == Concurrent::Agent.thread_pool #=> false
Concurrent::Defer.thread_pool == $GLOBAL_THREAD_POOL #=> false
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
