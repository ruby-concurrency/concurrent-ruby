`ScheduledTask` is a close relative of `Concurrent::Future` but with one important difference. A `Future` is set to execute as soon as possible whereas a `ScheduledTask` is set to execute at a specific time. This implementation is loosely based on Java's [ScheduledExecutorService](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ScheduledExecutorService.html). 

### Scheduling

The *intended* schedule time of task execution is set on object construction with first argument. The time can be a numeric (floating point or integer) representing a number of seconds in the future or it can ba a `Time` object representing the approximate time of execution. Any other value, a numeric equal to or less than zero, or a time in the past will result in an exception. 

The *actual* schedule time of task execution is set when the `execute` method is called. If the *intended* schedule time was given as a number of seconds then the *actual* schedule time will be calculated from the current time. If the *intended* schedule time was given as a `Time` object the current time will be checked against the *intended* schedule time. If the *intended* schedule time is now in the past an exception will be raised. 

The constructor can also be given zero or more processing options. Currently the only supported options are those recognized by the [Dereferenceable](Dereferenceable) module. 

The final constructor argument is a block representing the task to be performed at the scheduled time. If no block is given an `ArgumentError` will be raised.

#### States

`ScheduledTask` mixes in the  [Obligation](Obligation) module thus giving it "future" behavior. This includes the expected lifecycle states. `ScheduledTask` has one additional state, however. While the task (block) is being executed the state of the object will be `:in_progress`. This additional state is  necessary because it has implications for task cancellation. 

#### Cancellation

A `:pending` task can be cancelled using the `#cancel` method. A task in any other state, including `:in_progress`, cannot be cancelled. The `#cancel` method returns a boolean indicating the success of the cancellation attempt. A cancelled `ScheduledTask` cannot be restarted. It is immutable. 

### Obligation and Observation

The result of a `ScheduledTask` can be obtained either synchronously or asynchronously. `ScheduledTask` mixes in both the [Obligation](Obligation) module and the [Observable](http://ruby-doc.org/stdlib-2.0/libdoc/observer/rdoc/Observable.html) module from the Ruby standard library. With one exception `ScheduledTask` behaves identically to [Future](Observable) with regard to these modules. 

Unlike `Future`, however, an observer added to a `ScheduledTask` *after* the task operation has completed will *not* receive notification. The reason for this is the subtle but important difference in intent between the two abstractions. With a `Future` there is no way to know when the operation will complete. Therefore the *expected* behavior of an observer is to be notified. With a `ScheduledTask` however, the approximate time of execution is known. It is often explicitly set as a constructor argument. It is always available via the `#schedule_time` attribute reader. Therefore it is always possible for calling code to know whether the observer is being added prior to task execution. It is also easy to add an observer long before task execution begins (since there is never a reason to create a scheduled task that starts immediately). Subsequently, the *expectation* is that the caller of `#add_observer` is making the call within an appropriate time. 

### Examples

Successful task execution using seconds for scheduling:

```ruby
require 'concurrent'

task = Concurrent::ScheduledTask.new(2){ 'What does the fox say?' }
task.state         #=> :unscheduled
task.schedule_time #=> nil
task.execute
task.state         #=> pending
task.schedule_time #=> 2013-11-07 12:20:07 -0500

# wait for it...
sleep(3)

task.unscheduled? #=> false
task.pending?     #=> false
task.fulfilled?   #=> true
task.rejected?    #=> false
task.value        #=> 'What does the fox say?'
```

A `ScheduledTask` can be created and executed in one line:

```ruby
task = Concurrent::ScheduledTask.new(2){ 'What does the fox say?' }.execute
task.state         #=> pending
task.schedule_time #=> 2013-11-07 12:20:07 -0500
```

Failed task execution using a `Time` object for scheduling:

```ruby
t = Time.now + 2
task = Concurrent::ScheduledTask.execute(t){ raise StandardError.new('Call me maybe?') }
task.pending?      #=> true
task.schedule_time #=> 2013-11-07 12:22:01 -0500

# wait for it...
sleep(3)

task.unscheduled? #=> false
task.pending?     #=> false
task.fulfilled?   #=> false
task.rejected?    #=> true
task.value        #=> nil
task.reason       #=> #<StandardError: Call me maybe?> 
```

An exception will be thrown on creation if the schedule time is in the past:

```ruby
task = Concurrent::ScheduledTask.new(Time.now - 10){ nil }
  #=> ArgumentError: schedule time must be in the future

task = Concurrent::ScheduledTask.execute(-10){ nil }
  #=> ArgumentError: seconds must be greater than zero
```

An exception will also be thrown when `#execute` is called if the current time has
progressed past the intended schedule time:

```ruby
task = Concurrent::ScheduledTask.new(Time.now + 10){ nil }
sleep(20)

task.execute
  #=> ArgumentError: schedule time must be in the future
```

Task execution with observation:

```ruby
observer = Class.new{
  def update(time, value, reason)
    puts "The task completed at #{time} with value '#{value}'"
  end
}.new

task = Concurrent::ScheduledTask.new(2){ 'What does the fox say?' }
task.add_observer(observer)
task.execute
task.pending?      #=> true
task.schedule_time #=> 2013-11-07 12:20:07 -0500

# wait for it...
sleep(3)

#>> The task completed at 2013-11-07 12:26:09 -0500 with value 'What does the fox say?'
```
