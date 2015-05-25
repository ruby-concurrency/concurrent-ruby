### Simple asynchronous task

future = Concurrent.future { sleep 0.1; 1 + 1 } # evaluation starts immediately
    # => <#Concurrent::Edge::Future:0x7fa08385da60 pending blocks:[]>
future.completed?                                  # => false
# block until evaluated
future.value                                       # => 2
future.completed?                                  # => true


### Failing asynchronous task

future = Concurrent.future { raise 'Boom' }
    # => <#Concurrent::Edge::Future:0x7fa083834638 failed blocks:[]>
future.value                                       # => nil
future.value! rescue $!                            # => #<RuntimeError: Boom>
future.reason                                      # => #<RuntimeError: Boom>
# re-raising
raise future rescue $!                             # => #<RuntimeError: Boom>


### Chaining

head    = Concurrent.future { 1 } 
branch1 = head.then(&:succ) 
branch2 = head.then(&:succ).then(&:succ) 
branch1.zip(branch2).value                         # => [2, 3]
(branch1 & branch2).then { |(a, b)| a + b }.value
    # => 5
# pick only first completed
(branch1 | branch2).value                          # => 2


### Error handling

Concurrent.future { Object.new }.then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
    # => NoMethodError
Concurrent.future { Object.new }.then(&:succ).rescue { 1 }.then(&:succ).value
    # => 2
Concurrent.future { 1 }.then(&:succ).rescue { |e| e.message }.then(&:succ).value
    # => 3


### Delay

# will not evaluate until asked by #value or other method requiring completion
scheduledfuture = Concurrent.delay { 'lazy' }
    # => <#Concurrent::Edge::Future:0x7fa0831917b8 pending blocks:[]>
sleep 0.1 
future.completed?                                  # => true
future.value                                       # => nil

# propagates trough chain allowing whole or partial lazy chains

head    = Concurrent.delay { 1 }
    # => <#Concurrent::Edge::Future:0x7fa083172ef8 pending blocks:[]>
branch1 = head.then(&:succ)
    # => <#Concurrent::Edge::Future:0x7fa083171c88 pending blocks:[]>
branch2 = head.delay.then(&:succ)
    # => <#Concurrent::Edge::Future:0x7fa08294f528 pending blocks:[]>
join    = branch1 & branch2
    # => <#Concurrent::Edge::Future:0x7fa08294e218 pending blocks:[]>

sleep 0.1 # nothing will complete                  # => 0
[head, branch1, branch2, join].map(&:completed?)   # => [false, false, false, false]

branch1.value                                      # => 2
sleep 0.1 # forces only head to complete, branch 2 stays incomplete
    # => 0
[head, branch1, branch2, join].map(&:completed?)   # => [true, true, false, false]

join.value                                         # => [2, 2]


### Flatting

Concurrent.future { Concurrent.future { 1+1 } }.flat.value # waits for inner future
    # => 2

# more complicated example
Concurrent.future { Concurrent.future { Concurrent.future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value                                  # => 3


### Schedule

scheduled = Concurrent.schedule(0.1) { 1 }
    # => <#Concurrent::Edge::Future:0x7fa08224edf0 pending blocks:[]>

scheduled.completed?                               # => false
scheduled.value # available after 0.1sec           # => 1

# and in chain
scheduled = Concurrent.delay { 1 }.schedule(0.1).then(&:succ)
    # => <#Concurrent::Edge::Future:0x7fa0831f3d50 pending blocks:[]>
# will not be scheduled until value is requested
sleep 0.1 
scheduled.value # returns after another 0.1sec     # => 2


### Completable Future and Event

future = Concurrent.future
    # => <#Concurrent::Edge::CompletableFuture:0x7fa0831e8090 pending blocks:[]>
event  = Concurrent.event
    # => <#Concurrent::Edge::CompletableEvent:0x7fa0831dae68 pending blocks:[]>

# will be blocked until completed
t1     = Thread.new { future.value } 
t2     = Thread.new { event.wait } 

future.success 1
    # => <#Concurrent::Edge::CompletableFuture:0x7fa0831e8090 success blocks:[]>
future.success 1 rescue $!
    # => #<Concurrent::MultipleAssignmentError: multiple assignment>
future.try_success 2                               # => false
event.complete
    # => <#Concurrent::Edge::CompletableEvent:0x7fa0831dae68 completed blocks:[]>

[t1, t2].each &:join 


### Callbacks

queue  = Queue.new                                 # => #<Thread::Queue:0x007fa0831bac30>
future = Concurrent.delay { 1 + 1 }
    # => <#Concurrent::Edge::Future:0x7fa0831b96c8 pending blocks:[]>

future.on_success { queue << 1 } # evaluated asynchronously
    # => <#Concurrent::Edge::Future:0x7fa0831b96c8 pending blocks:[]>
future.on_success! { queue << 2 } # evaluated on completing thread
    # => <#Concurrent::Edge::Future:0x7fa0831b96c8 pending blocks:[]>

queue.empty?                                       # => true
future.value                                       # => 2
queue.pop                                          # => 2
queue.pop                                          # => 1


### Thread-pools

Concurrent.future(:fast) { 2 }.then(:io) { File.read __FILE__ }.wait
    # => <#Concurrent::Edge::Future:0x7fa08318b070 success blocks:[]>


### Interoperability with actors

actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end
    # => #<Concurrent::Actor::Reference /square (Concurrent::Actor::Utils::AdHoc)>

Concurrent.
    future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value                                          # => 6

actor.ask(2).then(&:succ).value                    # => 5


### Common use-cases Examples

# simple background processing
Concurrent.future { do_stuff }
    # => <#Concurrent::Edge::Future:0x7fa0839ee8e8 pending blocks:[]>

# parallel background processing
jobs = 10.times.map { |i| Concurrent.future { i } } 
Concurrent.zip(*jobs).value                        # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


# periodic task
def schedule_job
  Concurrent.schedule(1) { do_stuff }.
      rescue { |e| report_error e }.
      then { schedule_job }
end                                                # => :schedule_job

schedule_job
    # => <#Concurrent::Edge::Future:0x7fa082904f78 pending blocks:[]>


