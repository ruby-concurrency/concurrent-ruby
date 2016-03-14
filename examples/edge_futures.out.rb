
# adds factory methods like: future, event, delay, schedule, zip,
include Concurrent::Edge::FutureFactoryMethods

### Simple asynchronous task

future = future { sleep 0.1; 1 + 1 } # evaluation starts immediately
    # => <#Concurrent::Edge::Future:0x7fedf3042458 pending blocks:[]>
future.completed?                                  # => false
# block until evaluated
future.value                                       # => 2
future.completed?                                  # => true


### Failing asynchronous task

future = future { raise 'Boom' }
    # => <#Concurrent::Edge::Future:0x7fedf30397e0 pending blocks:[]>
future.value                                       # => nil
future.value! rescue $!                            # => #<RuntimeError: Boom>
future.reason                                      # => #<RuntimeError: Boom>
# re-raising
raise future rescue $!                             # => #<RuntimeError: Boom>


### Chaining

head    = succeeded_future 1 
branch1 = head.then(&:succ) 
branch2 = head.then(&:succ).then(&:succ) 
branch1.zip(branch2).value!                        # => [2, 3]
(branch1 & branch2).then { |a, b| a + b }.value!   # => 5
(branch1 & branch2).then(&:+).value!               # => 5
zip(branch1, branch2, branch1).then { |*values| values.reduce &:+ }.value!
    # => 7
# pick only first completed
(branch1 | branch2).value!                         # => 2

### Error handling

future { Object.new }.then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
    # => NoMethodError
future { Object.new }.then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
    # => 2
future { 1 }.then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied
    # => 3

failing_zip = succeeded_future(1) & failed_future(StandardError.new('boom'))
    # => <#Concurrent::Edge::Future:0x7fedf38e3378 failed blocks:[]>
failing_zip.result                                 # => [false, [1, nil], [nil, #<StandardError: boom>]]
failing_zip.then { |v| 'never happens' }.result    # => [false, [1, nil], [nil, #<StandardError: boom>]]
failing_zip.rescue { |a, b| (a || b).message }.value
    # => "boom"
failing_zip.chain { |success, values, reasons| [success, values.compact, reasons.compactß] }.value
    # => nil

### Delay

# will not evaluate until asked by #value or other method requiring completion
future = delay { 'lazy' }
    # => <#Concurrent::Edge::Future:0x7fedf38c0b20 pending blocks:[]>
sleep 0.1 
future.completed?                                  # => false
future.value                                       # => "lazy"

# propagates trough chain allowing whole or partial lazy chains

head    = delay { 1 }
    # => <#Concurrent::Edge::Future:0x7fedf480dc90 pending blocks:[]>
branch1 = head.then(&:succ)
    # => <#Concurrent::Edge::Future:0x7fedf480cd40 pending blocks:[]>
branch2 = head.delay.then(&:succ)
    # => <#Concurrent::Edge::Future:0x7fedf1163690 pending blocks:[]>
join    = branch1 & branch2
    # => <#Concurrent::Edge::Future:0x7fedf11624c0 pending blocks:[]>

sleep 0.1 # nothing will complete                  # => 0
[head, branch1, branch2, join].map(&:completed?)   # => [false, false, false, false]

branch1.value                                      # => 2
sleep 0.1 # forces only head to complete, branch 2 stays incomplete
    # => 0
[head, branch1, branch2, join].map(&:completed?)   # => [true, true, false, false]

join.value                                         # => [2, 2]


### Flatting

future { future { 1+1 } }.flat.value # waits for inner future
    # => 2

# more complicated example
future { future { future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value                                  # => 3


### Schedule

scheduled = schedule(0.1) { 1 }
    # => <#Concurrent::Edge::Future:0x7fedf387ad28 pending blocks:[]>

scheduled.completed?                               # => false
scheduled.value # available after 0.1sec           # => 1

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
    # => <#Concurrent::Edge::Future:0x7fedf383b448 pending blocks:[]>
# will not be scheduled until value is requested
sleep 0.1 
scheduled.value # returns after another 0.1sec     # => 2


### Completable Future and Event

future = completable_future
    # => <#Concurrent::Edge::CompletableFuture:0x7fe8d312f9d0 pending blocks:[]>
event  = event()
    # => <#Concurrent::Edge::CompletableEvent:0x7fedf1112f88 pending blocks:[]>
# Don't forget to keep the reference, `future.then { |v| v }` is incompletable

# will be blocked until completed
t1     = Thread.new { future.value } 
t2     = Thread.new { event.wait } 

future.success 1
    # => <#Concurrent::Edge::CompletableFuture:0x7fedf3820828 success blocks:[]>
future.success 1 rescue $!
    # => #<Concurrent::MultipleAssignmentError: Future can be completed only once. Current result is [true, 1, nil], trying to set [true, 1, nil]>
future.try_success 2                               # => false
event.complete
    # => <#Concurrent::Edge::CompletableEvent:0x7fedf1112f88 completed blocks:[]>

[t1, t2].each &:join 


### Callbacks

queue  = Queue.new                                 # => #<Thread::Queue:0x007fedf11432a0>
future = delay { 1 + 1 }
    # => <#Concurrent::Edge::Future:0x7fedf1141950 pending blocks:[]>

future.on_success { queue << 1 } # evaluated asynchronously
    # => <#Concurrent::Edge::Future:0x7fedf1141950 pending blocks:[]>
future.on_success! { queue << 2 } # evaluated on completing thread
    # => <#Concurrent::Edge::Future:0x7fedf1141950 pending blocks:[]>

queue.empty?                                       # => true
future.value                                       # => 2
queue.pop                                          # => 2
queue.pop                                          # => 1


### Thread-pools

future(:fast) { 2 }.then(:io) { File.read __FILE__ }.wait
    # => <#Concurrent::Edge::Future:0x7fedf1121a10 success blocks:[]>


### Interoperability with actors

actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end
    # => #<Concurrent::Actor::Reference:0x7fedf10e8508 /square (Concurrent::Actor::Utils::AdHoc)>


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value                                          # => 6

actor.ask(2).then(&:succ).value                    # => 5


### Interoperability with channels

ch1 = Concurrent::Channel.new
    # => #<Concurrent::Channel:0x007fedf10a8ea8 @buffer=#<Concurrent::Channel::Buffer::Unbuffered:0x007fedf10a8de0 @__lock__=#<Mutex:0x007fedf10a8980>, @__condition__=#<Thread::ConditionVariable:0x007fedf10a88e0>, @closed=false, @size=0, @capacity=1, @buffer=nil, @putting=[], @taking=[]>, @validator=#<Proc:0x007fedf3831f88@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>
ch2 = Concurrent::Channel.new
    # => #<Concurrent::Channel:0x007fedf10a32c8 @buffer=#<Concurrent::Channel::Buffer::Unbuffered:0x007fedf10a3188 @__lock__=#<Mutex:0x007fedf10a30e8>, @__condition__=#<Thread::ConditionVariable:0x007fedf10a30c0>, @closed=false, @size=0, @capacity=1, @buffer=nil, @putting=[], @taking=[]>, @validator=#<Proc:0x007fedf3831f88@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>

result = select(ch1, ch2)
    # => <#Concurrent::Edge::Future:0x7fedf10a1400 pending blocks:[]>
ch1.put 1                                          # => true
result.value!
    # => [1, #<Concurrent::Channel:0x007fedf10a8ea8 @buffer=#<Concurrent::Channel::Buffer::Unbuffered:0x007fedf10a8de0 @__lock__=#<Mutex:0x007fedf10a8980>, @__condition__=#<Thread::ConditionVariable:0x007fedf10a88e0>, @closed=false, @size=0, @capacity=1, @buffer=nil, @putting=[], @taking=[]>, @validator=#<Proc:0x007fedf3831f88@/Users/pitr/Workspace/public/concurrent-ruby/lib/concurrent/channel.rb:28 (lambda)>>]


future { 1+1 }.
    then_put(ch1)
    # => <#Concurrent::Edge::Future:0x7f8df49b4f90 pending blocks:[]>
result = future { '%02d' }.
    then_select(ch1, ch2).
    then { |format, (value, channel)| format format, value }
    # => <#Concurrent::Edge::Future:0x7fedf0a1f7d0 pending blocks:[]>
result.value!                                      # => "02"


### Common use-cases Examples

# simple background processing
future { do_stuff }
    # => <#Concurrent::Edge::Future:0x7fedf0a15cf8 pending blocks:[]>

# parallel background processing
jobs = 10.times.map { |i| future { i } } 
zip(*jobs).value                                   # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


# periodic task
@end = false                                       # => false

def schedule_job
  schedule(1) { do_stuff }.
      rescue { |e| StandardError === e ? report_error(e) : raise(e) }.
      then { schedule_job unless @end }
end                                                # => :schedule_job

schedule_job
    # => <#Concurrent::Edge::Future:0x7fedf09c6720 pending blocks:[]>
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
    # => #<Concurrent::Actor::Reference:0x7fedf09a6970 /db (Concurrent::Actor::Utils::AdHoc)>

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
    # => #<Concurrent::Actor::Reference:0x7fedf2058dd0 /DB-pool (Concurrent::Actor::Utils::Pool)>

concurrent_jobs = 11.times.map do |v|

  future { v }.
      # ask the DB_POOL with the `v`, only 5 at the time, rest is parallel
      then_ask(DB_POOL).
      then(&:size).
      rescue { |reason| reason.message }
end 

zip(*concurrent_jobs).value!
    # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "undefined method `size' for nil:NilClass"]
