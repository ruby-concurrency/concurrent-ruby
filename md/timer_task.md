# Being of Sound Mind

A very common currency pattern is to run a thread that performs a task at regular
intervals. The thread that peforms the task sleeps for the given interval then
waked up and performs the task. Later, rinse, repeat... This pattern causes two
problems. First, it is difficult to test the business logic of the task becuse the
task itself is tightly couple with the threading. Second, an exception in the task
can cause the entire thread to abend. In a long-running application where the task
thread is intended to run for days/weeks/years a crashed task thread can pose a real
problem. The `TimerTask` class alleviates both problems.

When a TimerTask is launched it starts a thread for monitoring the execution interval.
The TimerTask thread does not perform the task, however. Instead, the TimerTask
launches the task on a separat thread. The advantage of this approach is that if
the task crashes it will only kill the task thread, not the TimerTask thread. The
TimerTask thread can then log the success or failure of the task. The TimerTask
can even be configured with a timeout value allowing it to kill a task that runs
to long and then log the error.

One other advantage of the `TimerTask` class is that it forces the bsiness logic to
be completely decoupled from the threading logic. The business logic can be tested
separately then passed to the a TimerTask for scheduling and running.

The `TimerTask` is the yin to to the
[Supervisor's](https://github.com/jdantonio/concurrent-ruby/blob/master/md/supervisor.md)
yang. Where the `Supervisor` is intended to manage long-running threads that operate
continuously, the `TimerTask` is intended to manage fairly short operations that
occur repeatedly at regular intervals.

Unlike some of the others concurrency objects in the library, TimerTasks do not
run on the global thread pool. In my experience the types of tasks that will benefit
from the `TimerTask` class tend to also be long running. For this reason they get
their own thread every time the task is executed.

## Observation

`TimerTask` supports notification through the Ruby standard library
[Observable](http://ruby-doc.org/stdlib-1.9.3/libdoc/observer/rdoc/Observable.html)
module. On execution the `TimerTask` will notify the observers with thress arguments:
time of execution, the result of the block (or nil on failure), and any raised
exceptions (or nil on success). If the timeout interval is exceeded the observer
will receive a `Concurrent::TimeoutError` object as the third argument.

## Examples

A basic example:

```ruby
require 'concurrent'

ec = Concurrent::TimerTask.run{ puts 'Boom!' }

ec.execution_interval #=> 60 == Concurrent::TimerTask::EXECUTION_INTERVAL
ec.timeout_interval   #=> 30 == Concurrent::TimerTask::TIMEOUT_INTERVAL
ec.status             #=> "sleep"

# wait 60 seconds...
#=> 'Boom!'

ec.kill #=> true
```

Both the execution_interval and the timeout_interval can be configured:

```ruby
ec = Concurrent::TimerTask.run(execution_interval: 5, timeout_interval: 5) do
       puts 'Boom!'
     end

ec.runner.execution_interval #=> 5
ec.runner.timeout_interval   #=> 5
```

By default an `TimerTask` will wait for `:execution_interval` seconds before running the block.
To run the block immediately set the `:run_now` option to `true`:

```ruby
ec = Concurrent::TimerTask.run(run_now: true){ puts 'Boom!' }
#=> 'Boom!''
ec.thread.status #=> "sleep"
>> 
```

A simple example with observation:

```ruby
class TaskObserver
  def update(time, result, ex)
    if result
      print "(#{time}) Execution successfully returned #{result}\n"
    elsif ex.is_a?(Concurrent::TimeoutError)
      print "(#{time}) Execution timed out\n"
    else
      print "(#{time}) Execution failed with error #{ex}\n"
    end
  end
end

task = Concurrent::TimerTask.run!(execution_interval: 1, timeout_interval: 1){ 42 }
task.runner.add_observer(TaskObserver.new)

#=> (2013-10-13 19:08:58 -0400) Execution successfully returned 42
#=> (2013-10-13 19:08:59 -0400) Execution successfully returned 42
#=> (2013-10-13 19:09:00 -0400) Execution successfully returned 42
task.runner.stop


task = Concurrent::TimerTask.run!(execution_interval: 1, timeout_interval: 1){ sleep }
task.runner.add_observer(TaskObserver.new)

#=> (2013-10-13 19:07:25 -0400) Execution timed out
#=> (2013-10-13 19:07:27 -0400) Execution timed out
#=> (2013-10-13 19:07:29 -0400) Execution timed out
task.runner.stop

task = Concurrent::TimerTask.run!(execution_interval: 1){ raise StandardError }
task.runner.add_observer(TaskObserver.new)

#=> (2013-10-13 19:09:37 -0400) Execution failed with error StandardError
#=> (2013-10-13 19:09:38 -0400) Execution failed with error StandardError
#=> (2013-10-13 19:09:39 -0400) Execution failed with error StandardError
task.runner.stop
```

## Copyright

*Concurrent Ruby* is Copyright &copy; 2013 [Jerry D'Antonio](https://twitter.com/jerrydantonio).
It is free software and may be redistributed under the terms specified in the LICENSE file.

## License

Released under the MIT license.

http://www.opensource.org/licenses/mit-license.php  

> Permission is hereby granted, free of charge, to any person obtaining a copy  
> of this software and associated documentation files (the "Software"), to deal  
> in the Software without restriction, including without limitation the rights  
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
> copies of the Software, and to permit persons to whom the Software is  
> furnished to do so, subject to the following conditions:  
> 
> The above copyright notice and this permission notice shall be included in  
> all copies or substantial portions of the Software.  
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN  
> THE SOFTWARE.  
