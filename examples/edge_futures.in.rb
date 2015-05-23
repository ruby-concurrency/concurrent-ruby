### Simple asynchronous task

future = Concurrent.future { sleep 0.1; 1 + 1 } # evaluation starts immediately
future.completed?
# block until evaluated
future.value
future.completed?


### Failing asynchronous task

future = Concurrent.future { raise 'Boom' }
future.value
future.value! rescue $!
future.reason
# re-raising
raise future rescue $!


### Chaining

head    = Concurrent.future { 1 } #
branch1 = head.then(&:succ) #
branch2 = head.then(&:succ).then(&:succ) #
branch1.zip(branch2).value
(branch1 & branch2).then { |(a, b)| a + b }.value
# pick only first completed
(branch1 | branch2).value


### Error handling

Concurrent.future { Object.new }.then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
Concurrent.future { Object.new }.then(&:succ).rescue { 1 }.then(&:succ).value
Concurrent.future { 1 }.then(&:succ).rescue { |e| e.message }.then(&:succ).value


### Delay

# will not evaluate until asked by #value or other method requiring completion
scheduledfuture = Concurrent.delay { 'lazy' }
sleep 0.1 #
future.completed?
future.value

# propagates trough chain allowing whole or partial lazy chains

head    = Concurrent.delay { 1 }
branch1 = head.then(&:succ)
branch2 = head.delay.then(&:succ)
join    = branch1 & branch2

sleep 0.1 # nothing will complete
[head, branch1, branch2, join].map(&:completed?)

branch1.value
sleep 0.1 # forces only head to complete, branch 2 stays incomplete
[head, branch1, branch2, join].map(&:completed?)

join.value


### Flatting

Concurrent.future { Concurrent.future { 1+1 } }.flat.value # waits for inner future

# more complicated example
Concurrent.future { Concurrent.future { Concurrent.future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value


### Schedule

scheduled = Concurrent.schedule(0.1) { 1 }

scheduled.completed?
scheduled.value # available after 0.1sec

# and in chain
scheduled = Concurrent.delay { 1 }.schedule(0.1).then(&:succ)
# will not be scheduled until value is requested
sleep 0.1 #
scheduled.value # returns after another 0.1sec


### Completable Future and Event

future = Concurrent.future
event  = Concurrent.event

# will be blocked until completed
t1     = Thread.new { future.value } #
t2     = Thread.new { event.wait } #

future.success 1
future.success 1 rescue $!
future.try_success 2
event.complete

[t1, t2].each &:join #


### Callbacks

queue  = Queue.new
future = Concurrent.delay { 1 + 1 }

future.on_success { queue << 1 } # evaluated asynchronously
future.on_success! { queue << 2 } # evaluated on completing thread

queue.empty?
future.value
queue.pop
queue.pop


### Thread-pools

Concurrent.future(:fast) { 2 }.then(:io) { File.read __FILE__ }.wait


### Interoperability with actors

actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end

Concurrent.
    future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value

actor.ask(2).then(&:succ).value


### Common use-cases Examples

# simple background processing
Concurrent.future { do_stuff }

# parallel background processing
jobs = 10.times.map { |i| Concurrent.future { i } } #
Concurrent.zip(*jobs).value


# periodic task
def schedule_job
  Concurrent.schedule(1) { do_stuff }.
      rescue { |e| report_error e }.
      then { schedule_job }
end

schedule_job


