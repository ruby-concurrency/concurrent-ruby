## Background

Thread pools are neither a new idea nor an implementation of the actor pattern. Nevertheless, thread pools are still an extremely relevant concurrency tool. Every time a thread is created then subsequently destroyed there is overhead. Creating a pool of reusable worker threads then repeatedly' dipping into the pool can have huge performace benefits for a long-running application like a service. Ruby's blocks provide an excellent mechanism for passing a generic work request to a thread, making Ruby an excellent candidate language for thread pools. 

The inspiration for thread pools in this library is Java's `java.util.concurrent` implementation of [thread pools](java.util.concurrent). The `java.util.concurrent` library is a well-designed, stable, scalable, and battle-tested concurrency library. It provides three different implementations of thread pools. One of those implementations is simply a special case of the first and doesn't offer much advantage in Ruby, so only the first two (`FixedThreadPool` and `CachedThreadPool`) are implemented here. 

Thread pools share common behavior defined by several mixin modules including `Executor`. The most important method is `post` (aliased with the left-shift operator `<<`). The `post` method sends a block to the pool for future processing. 

A running thread pool can be shutdown in an orderly or disruptive manner. Once a thread pool has been shutdown it cannot be started again. The `shutdown` method can be used to initiate an orderly shutdown of the thread pool. All new `post` calls will reject the given block and immediately return `false`. Threads in the pool will continue to process all in-progress work and will process all tasks still in the queue. The `kill` method can be used to immediately shutdown the pool. All new `post` calls will reject the given block and immediately return `false`. Ruby's `Thread.kill` will be called on all threads in the pool, aborting all in-progress work. Tasks in the queue will be discarded. 

A client thread can choose to block and wait for pool shutdown to complete. This is useful when shutting down an application and ensuring the app doesn't exit before pool processing is complete. The method `wait_for_termination` will block for a maximum of the given number of seconds then return `true` if shutdown completed successfully or `false`. When the timeout value is `nil` the call will block indefinitely. Calling `wait_for_termination` on a stopped thread pool will immediately return `true`. 

Predicate methods are provided to describe the current state of the thread pool. Provided methods are `running?`, `shuttingdown?`, and `shutdown?`. The `shutdown` method will return true regardless of whether the pool was shutdown wil `shutdown` or `kill`. 

### FixedThreadPool

From the docs:

> Creates a thread pool that reuses a fixed number of threads operating off a shared unbounded queue.
> At any point, at most `nThreads` threads will be active processing tasks. If additional tasks are submitted
> when all threads are active, they will wait in the queue until a thread is available. If any thread terminates
> due to a failure during execution prior to shutdown, a new one will take its place if needed to execute
> subsequent tasks. The threads in the pool will exist until it is explicitly `shutdown`.

#### Examples

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

### CachedThreadPool

  From the docs:

  > Creates a thread pool that creates new threads as needed, but will reuse previously constructed threads when
  > they are available. These pools will typically improve the performance of programs that execute many short-lived
  > asynchronous tasks. Calls to [`post`] will reuse previously constructed threads if available. If no existing
  > thread is available, a new thread will be created and added to the pool. Threads that have not been used for
  > sixty seconds are terminated and removed from the cache. Thus, a pool that remains idle for long enough will
  > not consume any resources. Note that pools with similar properties but different details (for example,
      > timeout parameters) may be created using [`CachedThreadPool`] constructors.

#### Examples

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

### Other Executors

  There are several other thread pools and executors in this library. See the API documentation for more information:

  * [CachedThreadPool](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/CachedThreadPool.html)
  * [FixedThreadPool](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/FixedThreadPool.html)
  * [ImmediateExecutor](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ImmediateExecutor.html)
  * [PerThreadExecutor](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/PerThreadExecutor.html)
  * [SafeTaskExecutor](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/SafeTaskExecutor.html)
  * [SerializedExecution](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/SerializedExecution.html)
  * [SerializedExecutionDelegator](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/SerializedExecutionDelegator.html)
  * [SingleThreadExecutor](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/SingleThreadExecutor.html)
  * [ThreadPoolExecutor](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/ThreadPoolExecutor.html)
  * [TimerSet](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/TimerSet.html)

### Global Thread Pools

  For efficiency, Concurrent Ruby provides a few global thread pools. These executors are used by the higher-level abstractions for running asynchronous operations without creating new threads more often than necessary. These executors are lazy-loaded so they do not create overhead when not needed. The global executors may also be accessed directly if desired. For more information regarding the global thread pools and their configuration, refer to the [API documentation](http://ruby-concurrency.github.io/concurrent-ruby/Concurrent/Configuration.html).

#### Changing the Global Thread Pool

  It should rarely be necessary to reconfigure the global executors. If necessary, it is possible to change the gem configuration during application initialization. Gem configration must be done *before* the global executors are lazy-loaded. Once the global thread pools are initialized they may no longer be reconfigured. Doing so will raise an exception. 

```ruby
require 'concurrent'

Concurrent.configure do |config|
  config.global_operation_pool = Concurrent::CachedThreadPool.new
end
```
