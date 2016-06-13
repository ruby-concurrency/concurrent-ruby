# Promises Framework

Promises is a new framework unifying former `Concurrent::Future`, `Concurrent::Promise`, `Concurrent::IVar`,
`Concurrent::Event`, `Concurrent.dataflow`, `Delay`, and `TimerTask`. It extensively uses the new
synchronization layer to make all the features **non-blocking** and
**lock-free**, with the exception of obviously blocking operations like
`#wait`, `#value`. As a result it lowers a danger of deadlocking and offers
better performance.

## Overview

There are two central classes ... TODO

## Where does it executes?

-   TODO Explain `_on` `_using` sufixes.

## Old examples follow

*TODO rewrite into md with examples*

Adds factory methods like: future, event, delay, schedule, zip, etc. Otherwise
they can be called on Promises module.

```ruby
Concurrent::Promises::FactoryMethods.instance_methods false
# => [:completable_event,
#     :completable_event_on,
#     :completable_future,
#     :completable_future_on,
#     :future,
#     :future_on,
#     :completed_future,
#     :succeeded_future,
#     :failed_future,
#     :completed_event,
#     :delay,
#     :delay_on,
#     :schedule,
#     :schedule_on,
#     :zip_futures,
#     :zip_futures_on,
#     :zip,
#     :zip_events,
#     :zip_events_on,
#     :any_complete_future,
#     :any,
#     :any_complete_future_on,
#     :any_successful_future,
#     :any_successful_future_on,
#     :any_event,
#     :any_event_on,
#     :select]

include Concurrent::Promises::FactoryMethods #
```

Simple asynchronous task:

```ruby
future = future(0.1) { |duration| sleep duration; :result } # evaluation starts immediately
future.completed?                        # => false
# block until evaluated
future.value                             # => :result
future.completed?                        # => true
```

Failing asynchronous task

```ruby
future = future { raise 'Boom' }
# => <#Concurrent::Promises::Future:0x7f90a7886578 pending blocks:[]>
future.value                             # => nil
future.value! rescue $!                  # => #<RuntimeError: Boom>
future.reason                            # => #<RuntimeError: Boom>
# re-raising
raise future rescue $!                   # => #<RuntimeError: Boom>
```

Direct creation of completed futures

```ruby
succeeded_future(Object.new)
# => <#Concurrent::Promises::Future:0x7f90a699edd0 success blocks:[]>
failed_future(StandardError.new("boom"))
# => <#Concurrent::Promises::Future:0x7f90a699d408 failed blocks:[]>

### Chaining of futures

head    = succeeded_future 1 #
branch1 = head.then(&:succ) #
branch2 = head.then(&:succ).then(&:succ) #
branch1.zip(branch2).value!              # => [2, 3]
# zip is aliased as &
(branch1 & branch2).then { |a, b| a + b }.value!
# => 5
(branch1 & branch2).then(&:+).value!     # => 5
# or a class method zip from FactoryMethods can be used to zip multiple futures
zip(branch1, branch2, branch1).then { |*values| values.reduce &:+ }.value!
# => 7
# pick only first completed
any(branch1, branch2).value!             # => 2
(branch1 | branch2).value!               # => 2


### Arguments

# any supplied arguments are passed to the block, promises ensure that they are visible to the block

future('3') { |s| s.to_i }.then(2) { |a, b| a + b }.value
# => 5
succeeded_future(1).then(2, &:+).value   # => 3
succeeded_future(1).chain(2) { |success, value, reason, arg| value + arg }.value
# => 3


### Error handling

succeeded_future(Object.new).then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
succeeded_future(Object.new).then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
succeeded_future(1).then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied

failing_zip = succeeded_future(1) & failed_future(StandardError.new('boom'))
# => <#Concurrent::Promises::Future:0x7f90a6947918 failed blocks:[]>
failing_zip.result
# => [false, [1, nil], [nil, #<StandardError: boom>]]
failing_zip.then { |v| 'never happens' }.result
# => [false, [1, nil], [nil, #<StandardError: boom>]]
failing_zip.rescue { |a, b| (a || b).message }.value
# => "boom"
failing_zip.chain { |success, values, reasons| [success, values.compact, reasons.compactß] }.value
# => nil


### Delay

# will not evaluate until asked by #value or other method requiring completion
future = delay { 'lazy' }
# => <#Concurrent::Promises::Future:0x7f90a690d718 pending blocks:[]>
sleep 0.1 #
future.completed?                        # => false
future.value                             # => "lazy"

# propagates trough chain allowing whole or partial lazy chains

head    = delay { 1 }
# => <#Concurrent::Promises::Future:0x7f90a68edcb0 pending blocks:[]>
branch1 = head.then(&:succ)
# => <#Concurrent::Promises::Future:0x7f90a68d7460 pending blocks:[]>
branch2 = head.delay.then(&:succ)
# => <#Concurrent::Promises::Future:0x7f90a68d5368 pending blocks:[]>
join    = branch1 & branch2
# => <#Concurrent::Promises::Future:0x7f90a68b7e30 pending blocks:[]>

sleep 0.1 # nothing will complete
[head, branch1, branch2, join].map(&:completed?)
# => [false, false, false, false]

branch1.value                            # => 2
sleep 0.1 # forces only head to complete, branch 2 stays incomplete
[head, branch1, branch2, join].map(&:completed?)
# => [true, true, false, false]

join.value                               # => [2, 2]
[head, branch1, branch2, join].map(&:completed?)
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
# => <#Concurrent::Promises::Future:0x7f90a4243ab0 pending blocks:[]>

scheduled.completed?                     # => false
scheduled.value # available after 0.1sec

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
# => <#Concurrent::Promises::Future:0x7f90a4228d00 pending blocks:[]>
# will not be scheduled until value is requested
sleep 0.1 #
scheduled.value # returns after another 0.1sec


### Completable Future and Event

future = completable_future
# => <#Concurrent::Promises::CompletableFuture:0x7f90a6075dd0 pending blocks:[]>
event  = completable_event()
# => <#Concurrent::Promises::CompletableEvent:0x7f90a60741d8 pending blocks:[]>

# These threads will be blocked until the future and event is completed
t1     = Thread.new { future.value } #
t2     = Thread.new { event.wait } #

future.success 1
# => <#Concurrent::Promises::CompletableFuture:0x7f90a6075dd0 success blocks:[]>
future.success 1 rescue $!
# => #<Concurrent::MultipleAssignmentError: Future can be completed only once. Current result is [true, 1, nil], trying to set [true, 1, nil]>
future.success 2, false                  # => false
event.complete
# => <#Concurrent::Promises::CompletableEvent:0x7f90a60741d8 success blocks:[]>

# The threads can be joined now
[t1, t2].each &:join #


### Callbacks

queue  = Queue.new                       # => #<Thread::Queue:0x007f90a495ea48>
future = delay { 1 + 1 }
# => <#Concurrent::Promises::Future:0x7f90a4954f70 pending blocks:[]>

future.on_success { queue << 1 } # evaluated asynchronously
future.on_success! { queue << 2 } # evaluated on completing thread

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
# => #<Concurrent::Actor::Reference:0x7f90a41da290 /square (Concurrent::Actor::Utils::AdHoc)>


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value                                # => 6

actor.ask(2).then(&:succ).value          # => 5


### Interoperability with channels

ch1 = Concurrent::Channel.new
# => #<Concurrent::Channel:0x007f90a41aa1f8
#     @buffer=
#      #<Concurrent::Channel::Buffer::Unbuffered:0x007f90a41aa0b8
#       @__condition__=#<Thread::ConditionVariable:0x007f90a41a9f78>,
#       @__lock__=#<Mutex:0x007f90a41a9ff0>,
#       @buffer=nil,
#       @capacity=1,
#       @closed=false,
#       @putting=[],
#       @size=0,
#       @taking=[]>,
#     @validator=
#      #<Proc:0x007f90a6907200@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>
ch2 = Concurrent::Channel.new
# => #<Concurrent::Channel:0x007f90a491e448
#     @buffer=
#      #<Concurrent::Channel::Buffer::Unbuffered:0x007f90a491e3a8
#       @__condition__=#<Thread::ConditionVariable:0x007f90a491e308>,
#       @__lock__=#<Mutex:0x007f90a491e330>,
#       @buffer=nil,
#       @capacity=1,
#       @closed=false,
#       @putting=[],
#       @size=0,
#       @taking=[]>,
#     @validator=
#      #<Proc:0x007f90a6907200@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>

result = select(ch1, ch2)
# => <#Concurrent::Promises::Future:0x7f90a4180a60 pending blocks:[]>
ch1.put 1                                # => true
result.value!
# => [1,
#     #<Concurrent::Channel:0x007f90a41aa1f8
#      @buffer=
#       #<Concurrent::Channel::Buffer::Unbuffered:0x007f90a41aa0b8
#        @__condition__=#<Thread::ConditionVariable:0x007f90a41a9f78>,
#        @__lock__=#<Mutex:0x007f90a41a9ff0>,
#        @buffer=nil,
#        @capacity=1,
#        @closed=false,
#        @putting=[],
#        @size=0,
#        @taking=[]>,
#      @validator=
#       #<Proc:0x007f90a6907200@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>]


future { 1+1 }.
    then_put(ch1)
# => <#Concurrent::Promises::Future:0x7f90a6064918 pending blocks:[]>
result = future { '%02d' }.
    then_select(ch1, ch2).
    then { |format, (value, channel)| format format, value }
# => <#Concurrent::Promises::Future:0x7f90a4142cb0 pending blocks:[]>
result.value!                            # => "02"


### Common use-cases Examples

# simple background processing
future { do_stuff }
# => <#Concurrent::Promises::Future:0x7f90a4129a08 pending blocks:[]>

# parallel background processing
jobs = 10.times.map { |i| future { i } } #
zip(*jobs).value                         # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


# periodic task
def schedule_job(interval, &job)
  # schedule the first execution and chain restart og the job
  Concurrent.schedule(interval, &job).chain do |success, continue, reason|
    if success
      schedule_job(interval, &job) if continue
    else
      # handle error
      p reason
      # retry
      schedule_job(interval, &job)
    end
  end
end

queue = Queue.new                        # => #<Thread::Queue:0x007f90a40f8598>
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
arr, v = [], nil; arr << v while (v = queue.pop) #
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

  succeeded_future(v).
      # ask the DB with the `v`, only one at the time, rest is parallel
      then_ask(DB).
      # get size of the string, fails for 11
      then(&:size).
      rescue { |reason| reason.message } # translate error to value (exception, message)
end #

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

  succeeded_future(v).
      # ask the DB_POOL with the `v`, only 5 at the time, rest is parallel
      then_ask(DB_POOL).
      then(&:size).
      rescue { |reason| reason.message }
end #

zip(*concurrent_jobs).value!
# => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "undefined method `size' for nil:NilClass"]
```
