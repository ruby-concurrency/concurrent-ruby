# Adds factory methods like: future, event, delay, schedule, zip, ...
# otherwise they can be called on Promises module
include Concurrent::Promises::FutureFactoryMethods #


### Simple asynchronous task

future = future { sleep 0.1; 1 + 1 } # evaluation starts immediately
future.completed?
# block until evaluated
future.value
future.completed?


### Failing asynchronous task

future = future { raise 'Boom' }
future.value
future.value! rescue $!
future.reason
# re-raising
raise future rescue $!

### Direct creation of completed futures

succeeded_future(Object.new)
failed_future(StandardError.new("boom"))

### Chaining of futures

head    = succeeded_future 1 #
branch1 = head.then(&:succ) #
branch2 = head.then(&:succ).then(&:succ) #
branch1.zip(branch2).value!
# zip is aliased as &
(branch1 & branch2).then { |a, b| a + b }.value!
(branch1 & branch2).then(&:+).value!
# or a class method zip from FutureFactoryMethods can be used to zip multiple futures
zip(branch1, branch2, branch1).then { |*values| values.reduce &:+ }.value!
# pick only first completed
any(branch1, branch2).value!
(branch1 | branch2).value!


### Error handling

succeeded_future(Object.new).then(&:succ).then(&:succ).rescue { |e| e.class }.value # error propagates
succeeded_future(Object.new).then(&:succ).rescue { 1 }.then(&:succ).value # rescued and replaced with 1
succeeded_future(1).then(&:succ).rescue { |e| e.message }.then(&:succ).value # no error, rescue not applied

failing_zip = succeeded_future(1) & failed_future(StandardError.new('boom'))
failing_zip.result
failing_zip.then { |v| 'never happens' }.result
failing_zip.rescue { |a, b| (a || b).message }.value
failing_zip.chain { |success, values, reasons| [success, values.compact, reasons.compactß] }.value


### Delay

# will not evaluate until asked by #value or other method requiring completion
future = delay { 'lazy' }
sleep 0.1 #
future.completed?
future.value

# propagates trough chain allowing whole or partial lazy chains

head    = delay { 1 }
branch1 = head.then(&:succ)
branch2 = head.delay.then(&:succ)
join    = branch1 & branch2

sleep 0.1 # nothing will complete
[head, branch1, branch2, join].map(&:completed?)

branch1.value
sleep 0.1 # forces only head to complete, branch 2 stays incomplete
[head, branch1, branch2, join].map(&:completed?)

join.value
[head, branch1, branch2, join].map(&:completed?)


### Flatting

# waits for inner future, only the last call to value blocks thread
future { future { 1+1 } }.flat.value

# more complicated example
future { future { future { 1 + 1 } } }.
    flat(1).
    then { |f| f.then(&:succ) }.
    flat(1).value


### Schedule

# it'll be executed after 0.1 seconds
scheduled = schedule(0.1) { 1 }

scheduled.completed?
scheduled.value # available after 0.1sec

# and in chain
scheduled = delay { 1 }.schedule(0.1).then(&:succ)
# will not be scheduled until value is requested
sleep 0.1 #
scheduled.value # returns after another 0.1sec


### Completable Future and Event

future = completable_future
event  = event()

# These threads will be blocked until the future and event is completed
t1     = Thread.new { future.value } #
t2     = Thread.new { event.wait } #

future.success 1
future.success 1 rescue $!
future.try_success 2
event.complete

# The threads can be joined now
[t1, t2].each &:join #


### Callbacks

queue  = Queue.new
future = delay { 1 + 1 }

future.on_success { queue << 1 } # evaluated asynchronously
future.on_success! { queue << 2 } # evaluated on completing thread

queue.empty?
future.value
queue.pop
queue.pop


### Thread-pools

# Factory methods are taking names of the global executors
# (ot instances of custom executors)

future(:fast) { 2 }. # executed on :fast executor only short and non-blocking tasks can go there
    then(:io) { File.read __FILE__ }. # executed on executor for blocking and long operations
    wait


### Interoperability with actors

actor = Concurrent::Actor::Utils::AdHoc.spawn :square do
  -> v { v ** 2 }
end


future { 2 }.
    then_ask(actor).
    then { |v| v + 2 }.
    value

actor.ask(2).then(&:succ).value


### Interoperability with channels

ch1 = Concurrent::Channel.new
ch2 = Concurrent::Channel.new

result = select(ch1, ch2)
ch1.put 1
result.value!


future { 1+1 }.
    then_put(ch1)
result = future { '%02d' }.
    then_select(ch1, ch2).
    then { |format, (value, channel)| format format, value }
result.value!


### Common use-cases Examples

# simple background processing
future { do_stuff }

# parallel background processing
jobs = 10.times.map { |i| future { i } } #
zip(*jobs).value


# periodic task
# TODO (pitr-ch 14-Mar-2016): fix to be volatile
@end = false

def schedule_job
  schedule(1) { do_stuff }.
      rescue { |e| StandardError === e ? report_error(e) : raise(e) }.
      then { schedule_job unless @end }
end

schedule_job
@end = true


# How to limit processing where there are limited resources?
# By creating an actor managing the resource
DB   = Concurrent::Actor::Utils::AdHoc.spawn :db do
  data = Array.new(10) { |i| '*' * i }
  lambda do |message|
    # pretending that this queries a DB
    data[message]
  end
end

concurrent_jobs = 11.times.map do |v|

  future { v }.
      # ask the DB with the `v`, only one at the time, rest is parallel
      then_ask(DB).
      # get size of the string, fails for 11
      then(&:size).
      rescue { |reason| reason.message } # translate error to value (exception, message)
end #

zip(*concurrent_jobs).value!


# In reality there is often a pool though:
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

  future { v }.
      # ask the DB_POOL with the `v`, only 5 at the time, rest is parallel
      then_ask(DB_POOL).
      then(&:size).
      rescue { |reason| reason.message }
end #

zip(*concurrent_jobs).value!
