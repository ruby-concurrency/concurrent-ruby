# Promises Framework

Promises is a new framework unifying former `Concurrent::Future`,
`Concurrent::Promise`, `Concurrent::IVar`, `Concurrent::Event`,
`Concurrent.dataflow`, `Delay`, and `TimerTask`. It extensively uses the new
synchronization layer to make all the features *lock-free*, 
with the exception of obviously blocking operations like
`#wait`, `#value`, etc. As a result it lowers a danger of deadlocking and offers
better performance.

## Overview

*TODO*

-   What is it?
-   What is it for?
-   Main classes {Future}, {Event}
-   Explain pool usage :io vs :fast, and `_on` `_using` suffixes.

## Old examples follow

*TODO review pending*

Constructors are not accessible, instead there are many constructor methods in
FactoryMethods.

```ruby
Concurrent::Promises::FactoryMethods.instance_methods false
```

The module can be included or extended where needed.

```ruby
Class.new do
  include Concurrent::Promises::FactoryMethods

  def a_method
    resolvable_event
  end
end.new.a_method

Module.new { extend Concurrent::Promises::FactoryMethods }.resolvable_event
```
The module is already extended into {Promises} for convenience.

```ruby
Concurrent::Promises.resolvable_event
```

For this guide we include the module into `main` so we can call the factory
methods in following examples directly.

```ruby
include Concurrent::Promises::FactoryMethods #
resolvable_event
```

Simple asynchronous task:

```ruby
future = future(0.1) { |duration| sleep duration; :result } # evaluation starts immediately
future.resolved?
# block until evaluated
future.value
future.resolved?
```

Rejecting asynchronous task:

```ruby
future = future { raise 'Boom' }
future.value
future.value! rescue $!
future.reason
# re-raising
raise future rescue $!
```

Direct creation of resolved futures:

```ruby
fulfilled_future(Object.new)
rejected_future(StandardError.new("boom"))
```

Chaining of futures:

```ruby
head    = fulfilled_future 1 #
branch1 = head.then(&:succ) #
branch2 = head.then(&:succ).then(&:succ) #
branch1.zip(branch2).value!
# zip is aliased as &
(branch1 & branch2).then { |a, b| a + b }.value!
(branch1 & branch2).then(&:+).value!
# or a class method zip from FactoryMethods can be used to zip multiple futures
zip(branch1, branch2, branch1).then { |*values| values.reduce &:+ }.value!
# pick only first resolved
any(branch1, branch2).value!
(branch1 | branch2).value!
```

Any supplied arguments are passed to the block, promises ensure that they are visible to the block:

```ruby
future('3') { |s| s.to_i }.then(2) { |a, b| a + b }.value
fulfilled_future(1).then(2, &:+).value
fulfilled_future(1).chain(2) { |fulfilled, value, reason, arg| value + arg }.value
```

Error handling:

```ruby
fulfilled_future(Object.new).then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
fulfilled_future(Object.new).then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
fulfilled_future(1).then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied

rejected_zip = fulfilled_future(1) & rejected_future(StandardError.new('boom'))
rejected_zip.result
rejected_zip.then { |v| 'never happens' }.result
rejected_zip.rescue { |a, b| (a || b).message }.value
rejected_zip.chain { |fulfilled, values, reasons| [fulfilled, values.compact, reasons.compact] }.value
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
branch1 = head.then(&:succ)
branch2 = head.delay.then(&:succ)
join    = branch1 & branch2

sleep 0.1 # nothing will resolve
[head, branch1, branch2, join].map(&:resolved?)

branch1.value
sleep 0.1 # forces only head to resolve, branch 2 stays pending
[head, branch1, branch2, join].map(&:resolved?)

join.value
[head, branch1, branch2, join].map(&:resolved?)
```

When flatting, it waits for inner future. Only the last call to value blocks thread.

```ruby
future { future { 1+1 } }.flat.value

# more complicated example
future { future { future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value
```

Scheduling of asynchronous tasks:

```ruby

# it'll be executed after 0.1 seconds
scheduled = schedule(0.1) { 1 }

scheduled.resolved?
scheduled.value # available after 0.1sec

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
# will not be scheduled until value is requested
sleep 0.1 #
scheduled.value # returns after another 0.1sec
```

Resolvable Future and Event:

```ruby

future = resolvable_future
event  = resolvable_event()

# These threads will be blocked until the future and event is resolved
t1     = Thread.new { future.value } #
t2     = Thread.new { event.wait } #

future.fulfill 1
future.fulfill 1 rescue $!
future.fulfill 2, false
event.resolve

# The threads can be joined now
[t1, t2].each &:join #
```

Callbacks:

```ruby
queue  = Queue.new
future = delay { 1 + 1 }

future.on_fulfillment { queue << 1 } # evaluated asynchronously
future.on_fulfillment! { queue << 2 } # evaluated on resolving thread

queue.empty?
future.value
queue.pop
queue.pop
```

Factory methods are taking names of the global executors
(or instances of custom executors).

```ruby
# executed on :fast executor, only short and non-blocking tasks can go there
future_on(:fast) { 2 }.
    # executed on executor for blocking and long operations
    then_using(:io) { File.read __FILE__ }.
    wait
```

Interoperability with actors:

```ruby
actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value

actor.ask(2).then(&:succ).value
```

### Common use-cases Examples

#### simple background processing
  
```ruby
future { do_stuff }
```

#### parallel background processing

```ruby
jobs = 10.times.map { |i| future { i } } #
zip(*jobs).value
```

#### periodic task

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

queue = Queue.new
count = 0
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
arr, v = [], nil; arr << v while (v = queue.pop) #
# arr has the results from the executed scheduled tasks
arr
```
#### How to limit processing where there are limited resources?

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
end #

zip(*concurrent_jobs).value!
```

In reality there is often a pool though:

```ruby
data      = Array.new(10) { |i| '*' * i }
pool_size = 5

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
end #

zip(*concurrent_jobs).value!
```
