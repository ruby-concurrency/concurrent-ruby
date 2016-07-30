Promises is a new framework unifying former `Concurrent::Future`,
`Concurrent::Promise`, `Concurrent::IVar`, `Concurrent::Event`,
`Concurrent.dataflow`, `Delay`, and `TimerTask`. It extensively uses the new
synchronization layer to make all the features *lock-free*, 
with the exception of obviously blocking operations like
`#wait`, `#value`, etc. As a result it lowers a danger of deadlocking and offers
better performance.

*TODO*

-   What is it?
-   What is it for?
-   Main classes {Future}, {Event}
-   Explain pool usage :io vs :fast, and `_on` `_using` suffixes.

# Old examples

*TODO review pending*

Constructors are not accessible, instead there are many constructor methods in
FactoryMethods.

```ruby
Concurrent::Promises::FactoryMethods.instance_methods false
# => [:resolvable_event,
#     :resolvable_event_on,
#     :resolvable_future,
#     :resolvable_future_on,
#     :future,
#     :future_on,
#     :resolved_future,
#     :fulfilled_future,
#     :rejected_future,
#     :resolved_event,
#     :create,
#     :delay,
#     :delay_on,
#     :schedule,
#     :schedule_on,
#     :zip_futures,
#     :zip_futures_on,
#     :zip,
#     :zip_events,
#     :zip_events_on,
#     :any_resolved_future,
#     :any,
#     :any_resolved_future_on,
#     :any_fulfilled_future,
#     :any_fulfilled_future_on,
#     :any_event,
#     :any_event_on,
#     :select]
```

The module can be included or extended where needed.

```ruby
Class.new do
  include Concurrent::Promises::FactoryMethods

  def a_method
    resolvable_event
  end
end.new.a_method
# => <#Concurrent::Promises::ResolvableEvent:0x7fc5b1b085c8 pending blocks:[]>

Module.new { extend Concurrent::Promises::FactoryMethods }.resolvable_event
# => <#Concurrent::Promises::ResolvableEvent:0x7fc5b1b02088 pending blocks:[]>
```
The module is already extended into {Promises} for convenience.

```ruby
Concurrent::Promises.resolvable_event
# => <#Concurrent::Promises::ResolvableEvent:0x7fc5b1afac48 pending blocks:[]>
```

For this guide we include the module into `main` so we can call the factory
methods in following examples directly.

```ruby
include Concurrent::Promises::FactoryMethods 
resolvable_event
# => <#Concurrent::Promises::ResolvableEvent:0x7fc5b1af8830 pending blocks:[]>
```

Simple asynchronous task:

```ruby
future = future(0.1) { |duration| sleep duration; :result } # evaluation starts immediately
future.resolved?                         # => false
# block until evaluated
future.value                             # => :result
future.resolved?                         # => true
```

Rejecting asynchronous task:

```ruby
future = future { raise 'Boom' }
# => <#Concurrent::Promises::Future:0x7fc5b1ad9700 pending blocks:[]>
future.value                             # => nil
future.value! rescue $!                  # => #<RuntimeError: Boom>
future.reason                            # => #<RuntimeError: Boom>
# re-raising
raise future rescue $!                   # => #<RuntimeError: Boom>
```

Direct creation of resolved futures:

```ruby
fulfilled_future(Object.new)
# => <#Concurrent::Promises::Future:0x7fc5b1acaa70 fulfilled blocks:[]>
rejected_future(StandardError.new("boom"))
# => <#Concurrent::Promises::Future:0x7fc5b1ac97b0 rejected blocks:[]>
```

Chaining of futures:

```ruby
head    = fulfilled_future 1 
branch1 = head.then(&:succ) 
branch2 = head.then(&:succ).then(&:succ) 
branch1.zip(branch2).value!              # => [2, 3]
# zip is aliased as &
(branch1 & branch2).then { |a, b| a + b }.value!
# => 5
(branch1 & branch2).then(&:+).value!     # => 5
# or a class method zip from FactoryMethods can be used to zip multiple futures
zip(branch1, branch2, branch1).then { |*values| values.reduce &:+ }.value!
# => 7
# pick only first resolved
any(branch1, branch2).value!             # => 2
(branch1 | branch2).value!               # => 2
```

Any supplied arguments are passed to the block, promises ensure that they are visible to the block:

```ruby
future('3') { |s| s.to_i }.then(2) { |a, b| a + b }.value
# => 5
fulfilled_future(1).then(2, &:+).value   # => 3
fulfilled_future(1).chain(2) { |fulfilled, value, reason, arg| value + arg }.value
# => 3
```

Error handling:

```ruby
fulfilled_future(Object.new).then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
fulfilled_future(Object.new).then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
fulfilled_future(1).then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied

rejected_zip = fulfilled_future(1) & rejected_future(StandardError.new('boom'))
# => <#Concurrent::Promises::Future:0x7fc5b3051380 rejected blocks:[]>
rejected_zip.result
# => [false, [1, nil], [nil, #<StandardError: boom>]]
rejected_zip.then { |v| 'never happens' }.result
# => [false, [1, nil], [nil, #<StandardError: boom>]]
rejected_zip.rescue { |a, b| (a || b).message }.value
# => "boom"
rejected_zip.chain { |fulfilled, values, reasons| [fulfilled, values.compact, reasons.compact] }.value
# => [false, [1], [#<StandardError: boom>]]
```

Delay will not evaluate until asked by #value or other method requiring resolution.

``` ruby
future = delay { 'lazy' }
sleep 0.1 #
future.resolved?
future.value
```
It propagates trough chain allowing whole or partial lazy chains.
```ruby
head    = delay { 1 }
# => <#Concurrent::Promises::Future:0x7fc5b3021450 pending blocks:[]>
branch1 = head.then(&:succ)
# => <#Concurrent::Promises::Future:0x7fc5b301b398 pending blocks:[]>
branch2 = head.delay.then(&:succ)
# => <#Concurrent::Promises::Future:0x7fc5b30190c0 pending blocks:[]>
join    = branch1 & branch2
# => <#Concurrent::Promises::Future:0x7fc5b30138f0 pending blocks:[]>

sleep 0.1 # nothing will resolve
[head, branch1, branch2, join].map(&:resolved?)
# => [false, false, false, false]

branch1.value                            # => 2
sleep 0.1 # forces only head to resolve, branch 2 stays pending
[head, branch1, branch2, join].map(&:resolved?)
# => [true, true, false, false]

join.value                               # => [2, 2]
[head, branch1, branch2, join].map(&:resolved?)
# => [true, true, true, true]
```

When flatting, it waits for inner future. Only the last call to value blocks thread.

```ruby
future { future { 1+1 } }.flat.value     # => 2

# more complicated example
future { future { future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value                        # => 3
```

Scheduling of asynchronous tasks:

```ruby

# it'll be executed after 0.1 seconds
scheduled = schedule(0.1) { 1 }
# => <#Concurrent::Promises::Future:0x7fc5b1a2a7f0 pending blocks:[]>

scheduled.resolved?                      # => false
scheduled.value # available after 0.1sec

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
# => <#Concurrent::Promises::Future:0x7fc5b1a19a18 pending blocks:[]>
# will not be scheduled until value is requested
sleep 0.1 
scheduled.value # returns after another 0.1sec
```

Resolvable Future and Event:

```ruby

future = resolvable_future
# => <#Concurrent::Promises::ResolvableFuture:0x7fc5b19c17a0 pending blocks:[]>
event  = resolvable_event()
# => <#Concurrent::Promises::ResolvableEvent:0x7fc5b19c0468 pending blocks:[]>

# These threads will be blocked until the future and event is resolved
t1     = Thread.new { future.value } 
t2     = Thread.new { event.wait } 

future.fulfill 1
# => <#Concurrent::Promises::ResolvableFuture:0x7fc5b19c17a0 fulfilled blocks:[]>
future.fulfill 1 rescue $!
# => #<Concurrent::MultipleAssignmentError: Future can be resolved only once. Current result is [true, 1, nil], trying to set [true, 1, nil]>
future.fulfill 2, false                  # => false
event.resolve
# => <#Concurrent::Promises::ResolvableEvent:0x7fc5b19c0468 fulfilled blocks:[]>

# The threads can be joined now
[t1, t2].each &:join 
```

Callbacks:

```ruby
queue  = Queue.new                       # => #<Thread::Queue:0x007fc5b193b880>
future = delay { 1 + 1 }
# => <#Concurrent::Promises::Future:0x7fc5b193a9a8 pending blocks:[]>

future.on_fulfillment { queue << 1 } # evaluated asynchronously
future.on_fulfillment! { queue << 2 } # evaluated on resolving thread

queue.empty?                             # => true
future.value                             # => 2
queue.pop                                # => 2
queue.pop                                # => 1
```

Factory methods are taking names of the global executors
(or instances of custom executors).

```ruby
# executed on :fast executor, only short and non-blocking tasks can go there
future_on(:fast) { 2 }.
    # executed on executor for blocking and long operations
    then_on(:io) { File.read __FILE__ }.
    wait
```

Interoperability with actors:

```ruby
actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end
# => #<Concurrent::Actor::Reference:0x7fc5b18a37b0 /square (Concurrent::Actor::Utils::AdHoc)>


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value                                # => 6

actor.ask(2).then(&:succ).value          # => 5
```

# Common use-cases Examples

## simple background processing
  
```ruby
future { do_stuff }
# => <#Concurrent::Promises::Future:0x7fc5b186b4f0 pending blocks:[]>
```

## parallel background processing

```ruby
jobs = 10.times.map { |i| future { i } } 
zip(*jobs).value                         # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
```

## periodic task

```ruby
def schedule_job(interval, &job)
  # schedule the first execution and chain restart og the job
  Concurrent.schedule(interval, &job).chain do |fulfilled, continue, reason|
    if fulfilled
      schedule_job(interval, &job) if continue
    else
      # handle error
      p reason
      # retry sooner
      schedule_job(interval / 10, &job)
    end
  end
end

queue = Queue.new                        # => #<Thread::Queue:0x007fc5b10a9730>
count = 0                                # => 0
interval = 0.05 # small just not to delay execution of this example

schedule_job interval do
  queue.push count
  count += 1
  # to continue scheduling return true, false will end the task
  if count < 4
    # to continue scheduling return true
    true
  else
    # close the queue with nil to simplify reading it
    queue.push nil
    # to end the task return false
    false
  end
end

# read the queue
arr, v = [], nil; arr << v while (v = queue.pop) 
# arr has the results from the executed scheduled tasks
arr                                      # => [0, 1, 2, 3]
```
## How to limit processing where there are limited resources?

By creating an actor managing the resource

```ruby
DB = Concurrent::Actor::Utils::AdHoc.spawn :db do
  data = Array.new(10) { |i| '*' * i }
  lambda do |message|
    # pretending that this queries a DB
    data[message]
  end
end

concurrent_jobs = 11.times.map do |v|

  fulfilled_future(v).
      # ask the DB with the `v`, only one at the time, rest is parallel
      then_ask(DB).
      # get size of the string, rejects for 11
      then(&:size).
      rescue { |reason| reason.message } # translate error to value (exception, message)
end 

zip(*concurrent_jobs).value!
# => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "undefined method `size' for nil:NilClass"]
```

In reality there is often a pool though:

```ruby
data      = Array.new(10) { |i| '*' * i }
# => ["",
#     "*",
#     "**",
#     "***",
#     "****",
#     "*****",
#     "******",
#     "*******",
#     "********",
#     "*********"]
pool_size = 5                            # => 5

DB_POOL = Concurrent::Actor::Utils::Pool.spawn!('DB-pool', pool_size) do |index|
  # DB connection constructor
  Concurrent::Actor::Utils::AdHoc.spawn(name: "worker-#{index}", args: [data]) do |data|
    lambda do |message|
      # pretending that this queries a DB
      data[message]
    end
  end
end

concurrent_jobs = 11.times.map do |v|

  fulfilled_future(v).
      # ask the DB_POOL with the `v`, only 5 at the time, rest is parallel
      then_ask(DB_POOL).
      then(&:size).
      rescue { |reason| reason.message }
end 

zip(*concurrent_jobs).value!
# => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "undefined method `size' for nil:NilClass"]
```

# Experimental

## Cancellation

```ruby
source, token = Concurrent::Cancellation.create
# => [#<Concurrent::Cancellation:0x007fc5b19c1390
#      @Cancel=
#       <#Concurrent::Promises::ResolvableEvent:0x7fc5b19c1688 pending blocks:[<#Concurrent::Promises::EventWrapperPromise:0x7fc5b19c1250 pending>]>,
#      @ResolveArgs=[],
#      @Token=
#       #<Concurrent::Cancellation::Token:0x007fc5b19c0e18
#        @Cancel=<#Concurrent::Promises::Event:0x7fc5b19c11d8 pending blocks:[]>>>,
#     #<Concurrent::Cancellation::Token:0x007fc5b19c0e18
#      @Cancel=<#Concurrent::Promises::Event:0x7fc5b19c11d8 pending blocks:[]>>]

futures = Array.new(2) do
  future(token) do |token| 
    token.loop_until_canceled { Thread.pass }
    :done
  end
end
# => [<#Concurrent::Promises::Future:0x7fc5b1938ef0 pending blocks:[]>,
#     <#Concurrent::Promises::Future:0x7fc5b0a1f860 pending blocks:[]>]

sleep 0.05                               # => 0
source.cancel                            # => true
futures.map(&:value!)                    # => [:done, :done]
```

## Throttling

```ruby
data = (0..10).to_a                      # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
max_tree = Concurrent::Throttle.new 3
# => #<Concurrent::Throttle:0x007fc5b1888e10
#     @AtomicCanRun=#<Concurrent::AtomicReference:0x007fc5b1888de8>,
#     @Queue=#<Thread::Queue:0x007fc5b1888dc0>>

futures = data.map do |data|
  future(data) do |data| 
    # un-throttled
    data + 1 
  end.throttle(max_tree) do |trigger|
    # throttled, imagine it uses DB connections or other limited resource
    trigger.then { |v| v * 2 * 2 }  
  end
end 

futures.map(&:value!)
# => [4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44]
```
