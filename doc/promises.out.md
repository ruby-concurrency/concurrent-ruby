# Promises Framework

Promises is a new framework unifying former `Concurrent::Future`,
`Concurrent::Promise`, `Concurrent::IVar`, `Concurrent::Event`,
`Concurrent.dataflow`, `Delay`, and `TimerTask`. It extensively uses the new
synchronization layer to make all the features *non-blocking* and
*lock-free*, with the exception of obviously blocking operations like
`#wait`, `#value`, etc. As a result it lowers a danger of deadlocking and offers
better performance.

## Overview

*TODO*

-   What is it?
-   What is it for?
-   Main classes {Future}, {Event}
-   Explain `_on` `_using` suffixes.

## Old examples follow

*TODO rewrite into md with examples*

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
# => <#Concurrent::Promises::ResolvableEvent:0x7ff23c2ece18 pending blocks:[]>

Module.new { extend Concurrent::Promises::FactoryMethods }.resolvable_event
# => <#Concurrent::Promises::ResolvableEvent:0x7ff23c2e6ea0 pending blocks:[]>
```
The module is already extended into {Promises} for convenience.

```ruby
Concurrent::Promises.resolvable_event
# => <#Concurrent::Promises::ResolvableEvent:0x7ff23c2d7cc0 pending blocks:[]>
```

For this guide we include the module into `main` so we can call the factory
methods in following examples directly.

```ruby
include Concurrent::Promises::FactoryMethods 
resolvable_event
# => <#Concurrent::Promises::ResolvableEvent:0x7ff23c2d4e08 pending blocks:[]>
```

Simple asynchronous task:

```ruby
future = future(0.1) { |duration| sleep duration; :result } # evaluation starts immediately
future.resolved?                         # => false
# block until evaluated
future.value                             # => :result
future.resolved?                         # => true
```

Rejecting asynchronous task

```ruby
future = future { raise 'Boom' }
# => <#Concurrent::Promises::Future:0x7ff23c2be428 pending blocks:[]>
future.value                             # => nil
future.value! rescue $!                  # => #<RuntimeError: Boom>
future.reason                            # => #<RuntimeError: Boom>
# re-raising
raise future rescue $!                   # => #<RuntimeError: Boom>
```

Direct creation of resolved futures

```ruby
fulfilled_future(Object.new)
# => <#Concurrent::Promises::Future:0x7ff23c10e920 fulfilled blocks:[]>
rejected_future(StandardError.new("boom"))
# => <#Concurrent::Promises::Future:0x7ff23c106090 rejected blocks:[]>

### Chaining of futures

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


### Arguments

# any supplied arguments are passed to the block, promises ensure that they are visible to the block

future('3') { |s| s.to_i }.then(2) { |a, b| a + b }.value
# => 5
fulfilled_future(1).then(2, &:+).value   # => 3
fulfilled_future(1).chain(2) { |fulfilled, value, reason, arg| value + arg }.value
# => 3


### Error handling

fulfilled_future(Object.new).then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
fulfilled_future(Object.new).then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
fulfilled_future(1).then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied

rejected_zip = fulfilled_future(1) & rejected_future(StandardError.new('boom'))
# => <#Concurrent::Promises::Future:0x7ff23c08f350 rejected blocks:[]>
rejected_zip.result
# => [false, [1, nil], [nil, #<StandardError: boom>]]
rejected_zip.then { |v| 'never happens' }.result
# => [false, [1, nil], [nil, #<StandardError: boom>]]
rejected_zip.rescue { |a, b| (a || b).message }.value
# => "boom"
rejected_zip.chain { |fulfilled, values, reasons| [fulfilled, values.compact, reasons.compact] }.value
# => [false, [1], [#<StandardError: boom>]]


### Delay

# will not evaluate until asked by #value or other method requiring resolution
future = delay { 'lazy' }
# => <#Concurrent::Promises::Future:0x7ff23c064e70 pending blocks:[]>
sleep 0.1 
future.resolved?                         # => false
future.value                             # => "lazy"

# propagates trough chain allowing whole or partial lazy chains

head    = delay { 1 }
# => <#Concurrent::Promises::Future:0x7ff23c054408 pending blocks:[]>
branch1 = head.then(&:succ)
# => <#Concurrent::Promises::Future:0x7ff23c044a30 pending blocks:[]>
branch2 = head.delay.then(&:succ)
# => <#Concurrent::Promises::Future:0x7ff23c036840 pending blocks:[]>
join    = branch1 & branch2
# => <#Concurrent::Promises::Future:0x7ff23c034e78 pending blocks:[]>

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


### Flatting

# waits for inner future, only the last call to value blocks thread
future { future { 1+1 } }.flat.value     # => 2

# more complicated example
future { future { future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value                        # => 3


### Schedule

# it'll be executed after 0.1 seconds
scheduled = schedule(0.1) { 1 }
# => <#Concurrent::Promises::Future:0x7ff23d005aa0 pending blocks:[]>

scheduled.resolved?                      # => false
scheduled.value # available after 0.1sec

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
# => <#Concurrent::Promises::Future:0x7ff23b990b58 pending blocks:[]>
# will not be scheduled until value is requested
sleep 0.1 
scheduled.value # returns after another 0.1sec


### Resolvable Future and Event

future = resolvable_future
# => <#Concurrent::Promises::ResolvableFuture:0x7ff23b95a2b0 pending blocks:[]>
event  = resolvable_event()
# => <#Concurrent::Promises::ResolvableEvent:0x7ff23b9528f8 pending blocks:[]>

# These threads will be blocked until the future and event is resolved
t1     = Thread.new { future.value } 
t2     = Thread.new { event.wait } 

future.fulfill 1
# => <#Concurrent::Promises::ResolvableFuture:0x7ff23b95a2b0 fulfilled blocks:[]>
future.fulfill 1 rescue $!
# => #<Concurrent::MultipleAssignmentError: Future can be resolved only once. Current result is [true, 1, nil], trying to set [true, 1, nil]>
future.fulfill 2, false                  # => false
event.resolve
# => <#Concurrent::Promises::ResolvableEvent:0x7ff23b9528f8 fulfilled blocks:[]>

# The threads can be joined now
[t1, t2].each &:join 


### Callbacks

queue  = Queue.new                       # => #<Thread::Queue:0x007ff23b922e28>
future = delay { 1 + 1 }
# => <#Concurrent::Promises::Future:0x7ff23b9203f8 pending blocks:[]>

future.on_fulfillment { queue << 1 } # evaluated asynchronously
future.on_fulfillment! { queue << 2 } # evaluated on resolving thread

queue.empty?                             # => true
future.value                             # => 2
queue.pop                                # => 2
queue.pop                                # => 1


### Thread-pools

# Factory methods are taking names of the global executors
# (ot instances of custom executors)

# executed on :fast executor, only short and non-blocking tasks can go there
future_on(:fast) { 2 }.
    # executed on executor for blocking and long operations
    then_using(:io) { File.read __FILE__ }.
    wait


### Interoperability with actors

actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end
# => #<Concurrent::Actor::Reference:0x7ff23b8af568 /square (Concurrent::Actor::Utils::AdHoc)>


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value                                # => 6

actor.ask(2).then(&:succ).value          # => 5


### Interoperability with channels

ch1 = Concurrent::Channel.new
# => #<Concurrent::Channel:0x007ff23b85cef8
#     @buffer=
#      #<Concurrent::Channel::Buffer::Unbuffered:0x007ff23b85ce58
#       @__condition__=#<Thread::ConditionVariable:0x007ff23b85cca0>,
#       @__lock__=#<Mutex:0x007ff23b85cd18>,
#       @buffer=nil,
#       @capacity=1,
#       @closed=false,
#       @putting=[],
#       @size=0,
#       @taking=[]>,
#     @validator=
#      #<Proc:0x007ff23c3968f0@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>
ch2 = Concurrent::Channel.new
# => #<Concurrent::Channel:0x007ff23b0814b8
#     @buffer=
#      #<Concurrent::Channel::Buffer::Unbuffered:0x007ff23b0813c8
#       @__condition__=#<Thread::ConditionVariable:0x007ff23b081120>,
#       @__lock__=#<Mutex:0x007ff23b0812b0>,
#       @buffer=nil,
#       @capacity=1,
#       @closed=false,
#       @putting=[],
#       @size=0,
#       @taking=[]>,
#     @validator=
#      #<Proc:0x007ff23c3968f0@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>

result = select(ch1, ch2)
# => <#Concurrent::Promises::Future:0x7ff23b05a980 pending blocks:[]>
ch1.put 1                                # => true
result.value!
# => [1,
#     #<Concurrent::Channel:0x007ff23b85cef8
#      @buffer=
#       #<Concurrent::Channel::Buffer::Unbuffered:0x007ff23b85ce58
#        @__condition__=#<Thread::ConditionVariable:0x007ff23b85cca0>,
#        @__lock__=#<Mutex:0x007ff23b85cd18>,
#        @buffer=nil,
#        @capacity=1,
#        @closed=false,
#        @putting=[],
#        @size=0,
#        @taking=[]>,
#      @validator=
#       #<Proc:0x007ff23c3968f0@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>]


future { 1+1 }.
    then_put(ch1)
# => <#Concurrent::Promises::Future:0x7ff23ba19250 pending blocks:[]>
result = future { '%02d' }.
    then_select(ch1, ch2).
    then { |format, (value, channel)| format format, value }
# => <#Concurrent::Promises::Future:0x7ff23c3569f8 pending blocks:[]>
result.value!                            # => "02"


### Common use-cases Examples

# simple background processing
future { do_stuff }
# => <#Concurrent::Promises::Future:0x7ff23c336928 pending blocks:[]>

# parallel background processing
jobs = 10.times.map { |i| future { i } } 
zip(*jobs).value                         # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


# periodic task
def schedule_job(interval, &job)
  # schedule the first execution and chain restart og the job
  Concurrent.schedule(interval, &job).chain do |fulfilled, continue, reason|
    if fulfilled
      schedule_job(interval, &job) if continue
    else
      # handle error
      p reason
      # retry
      schedule_job(interval, &job)
    end
  end
end

queue = Queue.new                        # => #<Thread::Queue:0x007ff23d0ae808>
count = 0                                # => 0

schedule_job 0.05 do
  queue.push count
  count += 1
  # to continue scheduling return true, false will end the task
  if count < 4
    # to continue scheduling return true
    true
  else
    queue.push nil
    # to end the task return false
    false
  end
end

# read the queue
arr, v = [], nil; arr << v while (v = queue.pop) 
arr                                      # => [0, 1, 2, 3]

# How to limit processing where there are limited resources?
# By creating an actor managing the resource
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


# In reality there is often a pool though:
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
