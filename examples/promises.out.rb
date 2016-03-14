# Adds factory methods like: future, event, delay, schedule, zip, ...
# otherwise they can be called on Promises module
include Concurrent::Promises::FactoryMethods


### Simple asynchronous task

future = future { sleep 0.1; 1 + 1 } # evaluation starts immediately
    # => <#Concurrent::Promises::Future:0x7fae41b36630 pending blocks:[]>
future.completed?                                  # => false
# block until evaluated
future.value                                       # => 2
future.completed?                                  # => true


### Failing asynchronous task

future = future { raise 'Boom' }
    # => <#Concurrent::Promises::Future:0x7fae41b2d8f0 pending blocks:[]>
future.value                                       # => nil
future.value! rescue $!                            # => #<RuntimeError: Boom>
future.reason                                      # => #<RuntimeError: Boom>
# re-raising
raise future rescue $!                             # => #<RuntimeError: Boom>

### Direct creation of completed futures

succeeded_future(Object.new)
    # => <#Concurrent::Promises::Future:0x7fae41b25178 success blocks:[]>
failed_future(StandardError.new("boom"))
    # => <#Concurrent::Promises::Future:0x7fae41b24188 failed blocks:[]>

### Chaining of futures

head    = succeeded_future 1
branch1 = head.then(&:succ)
branch2 = head.then(&:succ).then(&:succ)
branch1.zip(branch2).value!                        # => [2, 3]
# zip is aliased as &
(branch1 & branch2).then { |a, b| a + b }.value!   # => 5
(branch1 & branch2).then(&:+).value!               # => 5
# or a class method zip from FactoryMethods can be used to zip multiple futures
zip(branch1, branch2, branch1).then { |*values| values.reduce &:+ }.value!
    # => 7
# pick only first completed
any(branch1, branch2).value!                       # => 2
(branch1 | branch2).value!                         # => 2


### Error handling

succeeded_future(Object.new).then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
    # => NoMethodError
succeeded_future(Object.new).then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
    # => 2
succeeded_future(1).then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied
    # => 3

failing_zip = succeeded_future(1) & failed_future(StandardError.new('boom'))
    # => <#Concurrent::Promises::Future:0x7fae41abe748 failed blocks:[]>
failing_zip.result                                 # => [false, [1, nil], [nil, #<StandardError: boom>]]
failing_zip.then { |v| 'never happens' }.result    # => [false, [1, nil], [nil, #<StandardError: boom>]]
failing_zip.rescue { |a, b| (a || b).message }.value
    # => "boom"
failing_zip.chain { |success, values, reasons| [success, values.compact, reasons.compactß] }.value
    # => nil


### Delay

# will not evaluate until asked by #value or other method requiring completion
future = delay { 'lazy' }
    # => <#Concurrent::Promises::Future:0x7fae41aa4938 pending blocks:[]>
sleep 0.1
future.completed?                                  # => false
future.value                                       # => "lazy"

# propagates trough chain allowing whole or partial lazy chains

head    = delay { 1 }
    # => <#Concurrent::Promises::Future:0x7fae41a94f38 pending blocks:[]>
branch1 = head.then(&:succ)
    # => <#Concurrent::Promises::Future:0x7fae41a94060 pending blocks:[]>
branch2 = head.delay.then(&:succ)
    # => <#Concurrent::Promises::Future:0x7fae41a76948 pending blocks:[]>
join    = branch1 & branch2
    # => <#Concurrent::Promises::Future:0x7fae41a75a48 pending blocks:[]>

sleep 0.1 # nothing will complete                  # => 0
[head, branch1, branch2, join].map(&:completed?)   # => [false, false, false, false]

branch1.value                                      # => 2
sleep 0.1 # forces only head to complete, branch 2 stays incomplete
    # => 1
[head, branch1, branch2, join].map(&:completed?)   # => [true, true, false, false]

join.value                                         # => [2, 2]
[head, branch1, branch2, join].map(&:completed?)   # => [true, true, true, true]


### Flatting

# waits for inner future, only the last call to value blocks thread
future { future { 1+1 } }.flat.value               # => 2

# more complicated example
future { future { future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value                                  # => 3


### Schedule

# it'll be executed after 0.1 seconds
scheduled = schedule(0.1) { 1 }
    # => <#Concurrent::Promises::Future:0x7fae419fcf80 pending blocks:[]>

scheduled.completed?                               # => false
scheduled.value # available after 0.1sec           # => 1

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
    # => <#Concurrent::Promises::Future:0x7fae4197ef68 pending blocks:[]>
# will not be scheduled until value is requested
sleep 0.1
scheduled.value # returns after another 0.1sec     # => 2


### Completable Future and Event

future = completable_future
    # => <#Concurrent::Promises::CompletableFuture:0x7fae4196c368 pending blocks:[]>
event  = event()
    # => <#Concurrent::Promises::CompletableEvent:0x7fae41965db0 pending blocks:[]>

# These threads will be blocked until the future and event is completed
t1     = Thread.new { future.value }
t2     = Thread.new { event.wait }

future.success 1
    # => <#Concurrent::Promises::CompletableFuture:0x7fae4196c368 success blocks:[]>
future.success 1 rescue $!
    # => #<Concurrent::MultipleAssignmentError: Future can be completed only once. Current result is [true, 1, nil], trying to set [true, 1, nil]>
future.try_success 2                               # => false
event.complete
    # => <#Concurrent::Promises::CompletableEvent:0x7fae41965db0 completed blocks:[]>

# The threads can be joined now
[t1, t2].each &:join


### Callbacks

queue  = Queue.new                                 # => #<Thread::Queue:0x007fae43071a68>
future = delay { 1 + 1 }
    # => <#Concurrent::Promises::Future:0x7fae4194ee58 pending blocks:[]>

future.on_success { queue << 1 } # evaluated asynchronously
    # => <#Concurrent::Promises::Future:0x7fae4194ee58 pending blocks:[]>
future.on_success! { queue << 2 } # evaluated on completing thread
    # => <#Concurrent::Promises::Future:0x7fae4194ee58 pending blocks:[]>

queue.empty?                                       # => true
future.value                                       # => 2
queue.pop                                          # => 2
queue.pop                                          # => 1


### Thread-pools

# Factory methods are taking names of the global executors
# (ot instances of custom executors)

future(:fast) { 2 }. # executed on :fast executor only short and non-blocking tasks can go there
    then(:io) { File.read __FILE__ }. # executed on executor for blocking and long operations
    wait
    # => <#Concurrent::Promises::Future:0x7fae4192eb08 success blocks:[]>


### Interoperability with actors

actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end
    # => #<Concurrent::Actor::Reference:0x7fae419045b0 /square (Concurrent::Actor::Utils::AdHoc)>


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value                                          # => 6

actor.ask(2).then(&:succ).value                    # => 5


### Interoperability with channels

ch1 = Concurrent::Channel.new
    # => #<Concurrent::Channel:0x007fae418adf08 @buffer=#<Concurrent::Channel::Buffer::Unbuffered:0x007fae418ade90 @__lock__=#<Mutex:0x007fae418addf0>, @__condition__=#<Thread::ConditionVariable:0x007fae418add78>, @closed=false, @size=0, @capacity=1, @buffer=nil, @putting=[], @taking=[]>, @validator=#<Proc:0x007fae419f5f78@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>
ch2 = Concurrent::Channel.new
    # => #<Concurrent::Channel:0x007fae418acfb8 @buffer=#<Concurrent::Channel::Buffer::Unbuffered:0x007fae418acea0 @__lock__=#<Mutex:0x007fae418acd88>, @__condition__=#<Thread::ConditionVariable:0x007fae418acd60>, @closed=false, @size=0, @capacity=1, @buffer=nil, @putting=[], @taking=[]>, @validator=#<Proc:0x007fae419f5f78@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>

result = select(ch1, ch2)
    # => <#Concurrent::Promises::Future:0x7fae418a7338 pending blocks:[]>
ch1.put 1                                          # => true
result.value!
    # => [1, #<Concurrent::Channel:0x007fae418adf08 @buffer=#<Concurrent::Channel::Buffer::Unbuffered:0x007fae418ade90 @__lock__=#<Mutex:0x007fae418addf0>, @__condition__=#<Thread::ConditionVariable:0x007fae418add78>, @closed=false, @size=0, @capacity=1, @buffer=nil, @putting=[], @taking=[]>, @validator=#<Proc:0x007fae419f5f78@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>]


future { 1+1 }.
    then_put(ch1)
    # => <#Concurrent::Promises::Future:0x7fae4189f098 pending blocks:[]>
result = future { '%02d' }.
    then_select(ch1, ch2).
    then { |format, (value, channel)| format format, value }
    # => <#Concurrent::Promises::Future:0x7fae411371c0 pending blocks:[]>
result.value!                                      # => "02"


### Common use-cases Examples

# simple background processing
future { do_stuff }
    # => <#Concurrent::Promises::Future:0x7fae43069070 pending blocks:[]>

# parallel background processing
jobs = 10.times.map { |i| future { i } }
zip(*jobs).value                                   # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


# periodic task
# TODO (pitr-ch 14-Mar-2016): fix to be volatile
@end = false                                       # => false

def schedule_job
  schedule(1) { do_stuff }.
      rescue { |e| StandardError === e ? report_error(e) : raise(e) }.
      then { schedule_job unless @end }
end                                                # => :schedule_job

schedule_job
    # => <#Concurrent::Promises::Future:0x7fae42900860 pending blocks:[]>
@end = true                                        # => true


# How to limit processing where there are limited resources?
# By creating an actor managing the resource
DB   = Concurrent::Actor::Utils::AdHoc.spawn :db do
  data = Array.new(10) { |i| '*' * i }
  lambda do |message|
    # pretending that this queries a DB
    data[message]
  end
end
    # => #<Concurrent::Actor::Reference:0x7fae428d2960 /db (Concurrent::Actor::Utils::AdHoc)>

concurrent_jobs = 11.times.map do |v|

  future { v }.
      # ask the DB with the `v`, only one at the time, rest is parallel
      then_ask(DB).
      # get size of the string, fails for 11
      then(&:size).
      rescue { |reason| reason.message } # translate error to value (exception, message)
end

zip(*concurrent_jobs).value!
    # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "undefined method `size' for nil:NilClass"]


# In reality there is often a pool though:
data      = Array.new(10) { |i| '*' * i }
    # => ["", "*", "**", "***", "****", "*****", "******", "*******", "********", "*********"]
pool_size = 5                                      # => 5

DB_POOL = Concurrent::Actor::Utils::Pool.spawn!('DB-pool', pool_size) do |index|
  # DB connection constructor
  Concurrent::Actor::Utils::AdHoc.spawn(name: "worker-#{index}", args: [data]) do |data|
    lambda do |message|
      # pretending that this queries a DB
      data[message]
    end
  end
end
    # => #<Concurrent::Actor::Reference:0x7fae42854498 /DB-pool (Concurrent::Actor::Utils::Pool)>

concurrent_jobs = 11.times.map do |v|

  future { v }.
      # ask the DB_POOL with the `v`, only 5 at the time, rest is parallel
      then_ask(DB_POOL).
      then(&:size).
      rescue { |reason| reason.message }
end

zip(*concurrent_jobs).value!
    # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "undefined method `size' for nil:NilClass"]
