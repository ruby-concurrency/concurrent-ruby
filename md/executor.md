# Being of Sound Mind

A very common currency pattern is to run a thread that performs a task at regular
intervals. The thread that peforms the task sleeps for the given interval then
waked up and performs the task. Later, rinse, repeat... This pattern causes two
problems. First, it is difficult to test the business logic of the task becuse the
task itself is tightly couple with the threading. Second, an exception in the task
can cause the entire thread to abend. In a long-running application where the task
thread is intended to run for days/weeks/years a crashed task thread can pose a real
problem. The `Executor` class alleviates both problems.

When an executor is launched it starts a thread for monitoring the execution interval.
The executor thread does not perform the task, however. Instead, the executor
launches the task on a separat thread. The advantage of this approach is that if
the task crashes it will only kill the task thread, not the executor thread. The
executor thread can then log the success or failure of the task. The executor
can even be configured with a timeout value allowing it to kill a task that runs
to long and then log the error.

One other advantage of the `Executor` class is that it forces the bsiness logic to
be completely decoupled from the threading logic. The business logic can be tested
separately then passed to the an executor for scheduling and running.

Unlike some of the others concurrency objects in the library, executors do not
run on the global. In my experience the types of tasks that will benefit from
the `Executor` class tend to also be long running. For this reason they get their
own thread every time the task is executed.

## ExecutionContext

When an executor is run the return value is an `ExecutionContext` object. An
`ExecutionContext` object has several attribute readers (`#name`, `#execution_interval`,
and `#timeout_interval`). It also provides several `Thread` operations which can
be performed against the internal thread. These include `#status`, `#join`, and
`kill`.

## Custom Logging

An executor will write a log message to standard out at the completion of every
task run. When the task is successful the log message is tagged at the `:info`
level. When the task times out the log message is tagged at the `warn` level.
When the task fails tocomplete (most likely because of exception) the log
message is tagged at the `error` level.

The default logging behavior can be overridden by passing a `proc` to the executor
on creation. The block will be passes three (3) arguments every time it is run:
executor `name`, log `level`, and the log `msg` (message). The `proc` can do
whatever it wanst with these arguments.

## Examples

A basic example:

```ruby
require 'concurrent'

ec = Concurrent::Executor.run('Foo'){ puts 'Boom!' }

ec.name               #=> "Foo"
ec.execution_interval #=> 60 == Concurrent::Executor::EXECUTION_INTERVAL
ec.timeout_interval   #=> 30 == Concurrent::Executor::TIMEOUT_INTERVAL
ec.status             #=> "sleep"

# wait 60 seconds...
#=> 'Boom!'
#=> ' INFO (2013-08-02 23:20:15) Foo: execution completed successfully'

ec.kill #=> true
```

Both the execution_interval and the timeout_interval can be configured:

```ruby
ec = Concurrent::Executor.run('Foo', execution_interval: 5, timeout_interval: 5) do
       puts 'Boom!'
     end

ec.execution_interval #=> 5
ec.timeout_interval   #=> 5
```

By default an `Executor` will wait for `:execution_interval` seconds before running the block.
To run the block immediately set the `:run_now` option to `true`:

```ruby
ec = Concurrent::Executor.run('Foo', run_now: true){ puts 'Boom!' }
#=> 'Boom!''
#=> ' INFO (2013-08-15 21:35:14) Foo: execution completed successfully'
ec.status #=> "sleep"
>> 
```

A simple example with timeout and task exception:

```ruby
ec = Concurrent::Executor.run('Foo', execution_interval: 1, timeout_interval: 1){ sleep(10) }

#=> WARN (2013-08-02 23:45:26) Foo: execution timed out after 1 seconds
#=> WARN (2013-08-02 23:45:28) Foo: execution timed out after 1 seconds
#=> WARN (2013-08-02 23:45:30) Foo: execution timed out after 1 seconds

ec = Concurrent::Executor.run('Foo', execution_interval: 1){ raise StandardError }

#=> ERROR (2013-08-02 23:47:31) Foo: execution failed with error 'StandardError'
#=> ERROR (2013-08-02 23:47:32) Foo: execution failed with error 'StandardError'
#=> ERROR (2013-08-02 23:47:33) Foo: execution failed with error 'StandardError'
```

For custom logging, simply provide a `proc` when creating an executor:

```ruby
file_logger = proc do |name, level, msg|
  open('executor.log', 'a') do |f|
    f << ("%5s (%s) %s: %s\n" % [level.upcase, Time.now.strftime("%F %T"), name, msg])
  end
end

ec = Concurrent::Executor.run('Foo', execution_interval: 5, logger: file_logger) do
       puts 'Boom!'
     end

# the log file contains
# INFO (2013-08-02 23:30:19) Foo: execution completed successfully
# INFO (2013-08-02 23:30:24) Foo: execution completed successfully
# INFO (2013-08-02 23:30:29) Foo: execution completed successfully
# INFO (2013-08-02 23:30:34) Foo: execution completed successfully
# INFO (2013-08-02 23:30:39) Foo: execution completed successfully
# INFO (2013-08-02 23:30:44) Foo: execution completed successfully
```

It is also possible to access the default stdout logger from within a logger `proc`:

```ruby
file_logger = proc do |name, level, msg|
  Concurrent::Executor::STDOUT_LOGGER.call(name, level, msg)
  open('executor.log', 'a') do |f|
    f << ("%5s (%s) %s: %s\n" % [level.upcase, Time.now.strftime("%F %T"), name, msg])
  end
end

ec = Concurrent::Executor.run('Foo', execution_interval: 5, logger: file_logger) do
       puts 'Boom!'
     end

# wait...

#=> Boom!
#=> INFO (2013-08-02 23:40:49) Foo: execution completed successfully
#=> Boom!
#=> INFO (2013-08-02 23:40:54) Foo: execution completed successfully
#=> Boom!
#=> INFO (2013-08-02 23:40:59) Foo: execution completed successfully

# and the log file contains
# INFO (2013-08-02 23:39:52) Foo: execution completed successfully
# INFO (2013-08-02 23:39:57) Foo: execution completed successfully
# INFO (2013-08-02 23:40:49) Foo: execution completed successfully
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
