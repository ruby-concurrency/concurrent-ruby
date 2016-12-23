# Basics

## Factory methods

Future and Event are created indirectly with constructor methods in
FactoryMethods. They are not designed for inheritance but rather for
composition.

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

The module is already extended into {Concurrent::Promises} for convenience.

```ruby
Concurrent::Promises.resolvable_event
```

For this guide we introduce a shortcut in `main` so we can call the factory
methods in following examples by using `Promisses` directly.

```ruby
Promises = Concurrent::Promises #
Promises.resolvable_event
```

## Asynchronous task

The most basic use-case of the framework is asynchronous processing. A task can
be processed asynchronously by using a `future` factory method. The block will
be executed on an internal thread pool.

Arguments of `future` are passed to the block and evaluation starts immediately.

```ruby
future = Promises.future(0.1) do |duration|
  sleep duration
  :result
end
```

Asks if the future is resolved, here it will be still in the middle of the
sleep call.

```ruby
future.resolved?
```

Retrieving the value will block until the future is resolved.

```ruby
future.value
future.resolved?
```

If the task fails we talk about the future being rejected.

```ruby
future = Promises.future { raise 'Boom' }
```

There is no result, the future was rejected with a reason.

```ruby
future.value
future.reason
```

It can be forced to raise the reason for rejection when retrieving the value.

```ruby
begin
  future.value! 
rescue => e 
  e
end
```

Which is the same as `future.value! rescue $!` which will be used hereafter.

Or it can be used directly as argument for raise, since it implements exception
method.

```ruby
raise future rescue $!
```

## States

Lets define a inspection helper for methods.

```ruby
def inspect_methods(*methods, of:)
  methods.reduce({}) { |h, m| h.update m => of.send(m) }
end #
```

Event has `pending` and `resolved` state. 

```ruby
event = Promises.resolvable_event #
inspect_methods(:state, :pending?, :resolved?, of: event)

event.resolve #
inspect_methods(:state, :pending?, :resolved?, of: event)
```

Future's `resolved` state is further specified to be `fulfilled` or `rejected`.

```ruby
future = Promises.resolvable_future #
inspect_methods(:state, :pending?, :resolved?, :fulfilled?, :rejected?, 
    of: future)

future.fulfill :value #
inspect_methods(:state, :pending?, :resolved?, :fulfilled?, :rejected?,
    :result, :value, :reason, of: future)

future = Promises.rejected_future StandardError.new #
inspect_methods(:state, :pending?, :resolved?, :fulfilled?, :rejected?, 
    :result, :value, :reason, of: future)
```

## Direct creation of resolved futures

When an existing value has to wrapped in a future it does not have to go
through evaluation as follows.

```ruby
Promises.future { :value }
```

Instead it can be created directly.

```ruby
Promises.fulfilled_future(:value)
Promises.rejected_future(StandardError.new('Ups'))
Promises.resolved_future(true, :value, nil)
Promises.resolved_future(false, nil, StandardError.new('Ups'))
```

## Chaining

Big advantage of promises is ability to chain tasks together without blocking
current thread.

```ruby
Promises.
    future(2) { |v| v.succ }.
    then(&:succ).
    value!
```

As `future` factory method takes argument, `then` method takes as well. Any
supplied arguments are passed to the block, and the library ensures that they
are visible to the block.

```ruby
Promises.
    future('3') { |s| s.to_i }.
    then(2) { |v, arg| v + arg }.
    value
Promises.
    fulfilled_future('3').
    then(&:to_i).
    then(2, &:+).
    value
Promises.
    fulfilled_future(1).
    chain(2) { |fulfilled, value, reason, arg| value + arg }.
    value
```

Passing the arguments in (similarly as for a thread `Thread.new(arg) { |arg|
do_stuff arg }`) is **required**, both following examples may break.

```ruby
arg = 1
Thread.new { do_stuff arg }
Promises.future { do_stuff arg }
```

## Branching, and zipping

Besides chaining it can also be branched.

```ruby
head    = Promises.fulfilled_future -1 #
branch1 = head.then(&:abs) #
branch2 = head.then(&:succ).then(&:succ) #

branch1.value!
branch2.value!
```

It can be combined back to one future by zipping (`zip`, `&`).

```ruby
branch1.zip(branch2).value!
(branch1 & branch2).
    then { |a, b| a + b }.
    value!
(branch1 & branch2).
    then(&:+).
    value!
Promises.
    zip(branch1, branch2, branch1).
    then { |*values| values.reduce(&:+) }.
    value!
```

Instead of zipping only the first one can be taken if needed.

```ruby
Promises.any(branch1, branch2).value!
(branch1 | branch2).value!
```

## Blocking methods

In these examples we have used blocking methods like `value` extensively for
their convenience, however in practice is better to avoid them and continue
chaining.

If they need to be used (e.g. when integrating with threads), `value!` is a
better option over `value` when rejections are not dealt with differently.
Otherwise the rejection are not handled and probably silently forgotten.

## Error handling

When one of the tasks in the chain fails, the rejection propagates down the
chain without executing the tasks created with `then`.

```ruby
Promises.
    fulfilled_future(Object.new).
    then(&:succ).
    then(&:succ).
    result
```

As `then` chained tasks execute only on fulfilled futures, there is a `rescue`
method which chains a task which is executed only when the future is rejected. 
It can be used to recover from rejection.

Using rescue to fulfill to 0 instead of the error.

```ruby
Promises.
    fulfilled_future(Object.new).
    then(&:succ).
    then(&:succ).
    rescue { |err| 0 }.
    result
```

Rescue not executed when there is no rejection.

```ruby
Promises.
    fulfilled_future(1).
    then(&:succ).
    then(&:succ).
    rescue { |e| 0 }. 
    result
```

Tasks added with `chain` are evaluated always.

```ruby
Promises.
    fulfilled_future(1).
    chain { |fulfilled, value, reason| fulfilled ? value : reason }.
    value!
Promises.
    rejected_future(StandardError.new('Ups')).
    chain { |fulfilled, value, reason| fulfilled ? value : reason }.
    value!
```

Zip is rejected if any of the zipped futures is.

```ruby
rejected_zip = Promises.zip(
    Promises.fulfilled_future(1),
    Promises.rejected_future(StandardError.new('Ups')))
rejected_zip.result
rejected_zip.
    rescue { |reason1, reason2| (reason1 || reason2).message }.
    value
```

## Delayed futures

Delayed futures will not evaluate until asked by `touch` or other method
requiring resolution. 

```ruby
future = Promises.delay { sleep 0.1; 'lazy' }
sleep 0.1 #
future.resolved?
future.touch
sleep 0.2 #
future.resolved?
```

All blocking methods like `wait`, `value` call `touch` and trigger evaluation.

```ruby
Promises.delay { :value }.value
```

It propagates trough chain up allowing whole or partial lazy chains.

```ruby
head    = Promises.delay { 1 } #
branch1 = head.then(&:succ) #
branch2 = head.delay.then(&:succ) #
join    = branch1 & branch2 #

sleep 0.1 #
```

Nothing resolves.

```ruby
[head, branch1, branch2, join].map(&:resolved?)
```

Force `branch1` evaluation.

```ruby
branch1.value
sleep 0.1 #
[head, branch1, branch2, join].map(&:resolved?)
```

Force evaluation of both by calling `value` on `join`.

```ruby
join.value
[head, branch1, branch2, join].map(&:resolved?)
```

## Flatting

Sometimes it is needed to wait for a inner future. Apparent solution is to wait
inside the future `Promises.future { Promises.future { 1+1 }.value }.value`
however as mentioned before, `value` calls should be **avoided** to avoid
blocking threads. Therefore there is a flat method which is a correct solution
in this situation and does not block any thread.

```ruby
Promises.future { Promises.future { 1+1 } }.flat.value!
```

A more complicated example.
```ruby
Promises.
    future { Promises.future { Promises.future { 1 + 1 } } }.
    flat(1).
    then { |future| future.then(&:succ) }.
    flat(1).
    value!
```

## Scheduling

Tasks can be planned to be executed with a time delay.

Schedule task to be executed in 0.1 seconds.

```ruby
scheduled = Promises.schedule(0.1) { 1 }
scheduled.resolved?
```

Value will become available after 0.1 seconds. 

```ruby
scheduled.value
```

It can be used in the chain as well, where the delay is counted form a moment
its parent resolves. Therefore following future will be resolved in 0.2 seconds.

```ruby
future = Promises.
    future { sleep 0.1; :result }.
    schedule(0.1).
    then(&:to_s).
    value!
```

Time can be used as well.

```ruby
Promises.schedule(Time.now + 10) { :val }
```

## Resolvable Future and Event:

Sometimes it is required to resolve a future externally, in these cases
`resolvable_future` and `resolvable_event` factory methods can be uses. See
{Concurrent::Promises::ResolvableFuture} and
{Concurrent::Promises::ResolvableEvent}.

```ruby
future = Promises.resolvable_future
```

The thread will be blocked until the future is resolved

```ruby
thread = Thread.new { future.value } #
future.fulfill 1
thread.value
```

Future can be resolved only once.

```ruby
future.fulfill 1 rescue $!
future.fulfill 2, false
```

# Advanced

## Callbacks

```ruby
queue  = Queue.new
future = Promises.delay { 1 + 1 }

future.on_fulfillment { queue << 1 } # evaluated asynchronously
future.on_fulfillment! { queue << 2 } # evaluated on resolving thread

queue.empty?
future.value
queue.pop
queue.pop
```

## Using executors

Factory methods, chain, and callback methods have all other version of them
which takes executor argument.

It takes an instance of an executor or a symbol which is a shortcuts for the
two global pools in concurrent-ruby. `fast` for short and non-blocking tasks
and `:io` for blocking and long tasks.

```ruby
Promises.future_on(:fast) { 2 }.
    then_on(:io) { File.read __FILE__ }.
    value.size
```

# Interoperability

## Actors

Create an actor which takes received numbers and returns the number squared. 

```ruby
actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end
```

Send result of `1+1` to the actor, and add 2 to the result send back from the
actor.

```ruby
Promises.
    future { 1 + 1 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value!
```

So `(1 + 1)**2 + 2 = 6`.

The `ask` method returns future.

```ruby
actor.ask(2).then(&:succ).value!
```

## Channels

> *TODO: To be added*

# Use-cases

## Simple background processing
  
```ruby
Promises.future { do_stuff }
```

## Parallel background processing

```ruby
tasks = 4.times.map { |i| Promises.future(i) { |i| i*2 } }
Promises.zip(*tasks).value!
```

## Actor background processing

Actors are mainly keep and isolate state, they should stay responsive not being
blocked by a longer running computations. It desirable to offload the work to
stateless promises.

Lets define an actor which will process jobs, while staying responsive, and
tracking the number of tasks being processed.

```ruby
class Computer < Concurrent::Actor::RestartingContext
  def initialize
    super()
    @jobs = {}
  end

  def on_message(msg)
    command, *args = msg
    case command
    # new job to process
    when :run
      job        = args[0]
      @jobs[job] = envelope.future
      # Process asynchronously and send message back when done.
      Concurrent::Promises.future(&job).chain(job) do |fulfilled, value, reason, job|
        self.tell [:done, job, fulfilled, value, reason]
      end
      # Do not make return value of this method to be answer of this message.
      # We are answering later in :done by resolving the future kept in @jobs.
      Concurrent::Actor::Behaviour::MESSAGE_PROCESSED
    when :done
      job, fulfilled, value, reason = *args
      future                        = @jobs.delete job
      # Answer the job's result.
      future.resolve fulfilled, value, reason
    when :status
      { running_jobs: @jobs.size }
    else
      # Continue to fail with unknown message.
      pass 
    end
  end
end
```

Create the computer actor and send it 3 jobs.

```ruby
computer = Concurrent::Actor.spawn Computer, :computer
results = 3.times.map { computer.ask [:run, -> { sleep 0.1; :result }] }
computer.ask(:status).value!
results.map(&:value!)
```
## Too many threads / fibers

Sometimes an application requires to process a lot of tasks concurrently. If
the number of concurrent tasks is high enough than it is not possible to create
a Thread for each of them. A partially satisfactory solution could be to use
Fibers, but that solution locks the application on MRI since other Ruby
implementations are using threads for each Fiber.

This library provides a {Concurrent::Promises::Future#run} method on a future
to simulate threads without actually accepting one all the time. The run method
is similar to {Concurrent::Promises::Future#flat} but it will keep flattening
until it's fulfilled with non future value, then the value is taken as a result
of the process simulated by `run`.

```ruby
body = lambda do |v|
  # Some computation step of the process    
  new_v = v + 1
  # Is the process finished?
  if new_v < 5
    # Continue computing with new value, does not have to be recursive.
    # It just has to return a future.
    Promises.future(new_v, &body)
  else
    # The process is finished, fulfill the final value with `new_v`.
    new_v
  end
end
Promises.future(0, &body).run.value! # => 5
```

This solution works well an any Ruby implementation.

> TODO add more complete example

## Cancellation

### Simple

Lets have two processes which will count until cancelled.

```ruby
source, token = Concurrent::Cancellation.create

count_until_cancelled = -> token, count do
  if token.canceled?
    count
  else
    Promises.future token, count+1, &count_until_cancelled
  end
end #

futures = Array.new(2) do
  Promises.future(token, 0, &count_until_cancelled).run
end

sleep 0.01 #
source.cancel
futures.map(&:value!)
```

Cancellation can also be used as event or future to log or plan re-execution.

```ruby
token.to_event.chain do
  # log cancellation
  # plane re-execution
end
```

### Parallel background processing with cancellation

Each task tries to count to 1000 but there is a randomly failing test. The
tasks share a cancellation, when one of them fails it cancels the others.

```ruby
source, token = Concurrent::Cancellation.create
tasks = 4.times.map do |i|
  Promises.future(source, token, i) do |source, token, i|
    count = 0
    1000.times do
      break count = :cancelled if token.canceled?
      count += 1
      sleep 0.01
      if rand > 0.95
        source.cancel
        raise 'random error'
      end
      count
    end
  end
end
Promises.zip(*tasks).result
```

Without the randomly failing part it produces following.

```ruby
source, token = Concurrent::Cancellation.create
tasks = 4.times.map do |i|
  Promises.future(source, token, i) do |source, token, i|
    count = 0
    1000.times do
      break count = :cancelled if token.canceled?
      count += 1
      # sleep 0.01
      # if rand > 0.95
      #   source.cancel
      #   raise 'random error'
      # end
    end
    count
  end
end
Promises.zip(*tasks).result
```

## Throttling concurrency

By creating an actor managing the resource we can control how many threads is
accessing the resource. In this case one at the time.

```ruby
data      = Array.new(10) { |i| '*' * i }
DB = Concurrent::Actor::Utils::AdHoc.spawn :db, data do |data|
  lambda do |message|
    # pretending that this queries a DB
    data[message]
  end
end

concurrent_jobs = 11.times.map do |v|
  DB.
      # ask the DB with the `v`, only one at the time, rest is parallel
      ask(v).
      # get size of the string, rejects for 11
      then(&:size).
      # translate error to a value (message of the exception)
      rescue { |reason| reason.message } 
end #

Promises.zip(*concurrent_jobs).value!
```

Often there is more then one DB connections, then the pool can be used.

```ruby
pool_size = 5

DB_POOL = Concurrent::Actor::Utils::Pool.spawn!('DB-pool', pool_size) do |index|
  # DB connection constructor
  Concurrent::Actor::Utils::AdHoc.spawn(
      name: "connection-#{index}", 
      args: [data]) do |data|
    lambda do |message|
      # pretending that this queries a DB
      data[message]
    end
  end
end

concurrent_jobs = 11.times.map do |v|
  DB_POOL.
      # ask the DB with the `v`, only one at the time, rest is parallel
      ask(v).
      # get size of the string, rejects for 11
      then(&:size).
      # translate error to a value (message of the exception)
      rescue { |reason| reason.message } 
end #

Promises.zip(*concurrent_jobs).value!
```

In other cases the DB adapter maintains its internal connection pool and we
just need to limit concurrent access to the DB's API to avoid the calls being
blocked.

Lets pretend that the `#[]` method on `DB_INTERNAL_POOL` is using the internal
pool of size 3. We create throttle with the same size

```ruby
DB_INTERNAL_POOL = Concurrent::Array.new data 

max_tree = Promises::Throttle.new 3

futures = 11.times.map do |i|
  max_tree.
      # throttled tasks, at most 3 simultaneous calls of [] on the database
      then_throttled { DB_INTERNAL_POOL[i] }.
      # un-throttled tasks, unlimited concurrency
      then { |starts| starts.size }.
      rescue { |reason| reason.message }
end #

futures.map(&:value!)
```

## Long stream of tasks

> TODO Channel

## Parallel enumerable ?

> TODO

## Periodic task

> TODO revisit, use cancellation, add to library

```ruby
def schedule_job(interval, &job)
  # schedule the first execution and chain restart of the job
  Promises.schedule(interval, &job).chain do |fulfilled, continue, reason|
    if fulfilled
      schedule_job(interval, &job) if continue
    else
      # handle error
      reason
      # retry sooner
      schedule_job(interval, &job)
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

