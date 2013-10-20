# You don't need to get no supervisor! You the supervisor today!

One of Erlang's claim to fame is its fault tolerance. Erlang systems have been known
to exhibit near-mythical levels of uptime. One of the main reasons is the pervaisve
design philosophy of "let it fail." When errors occur most Erlang systems simply let
the failing component fail completely. The system then restarts the failed component.
This "let it fail" resilience isn't an intrinsic capability of either the language
or the virtual machine. It's a deliberate design philosophy. One of the key enablers
of this philosophy is the [Supervisor](http://www.erlang.org/doc/man/supervisor.html)
of the OTP (standard library).

The Supervisor module answers the question "Who watches the watchmen?" A single
Supervisor can manage any number of workers (children). The Supervisor assumes
responsibility for starting the children, stopping them, and restarting them if
they fail. Several classes in this library, including `Actor` and `TimerTask` are
designed to work with `Supervisor`. Additionally, `Supervisor`s can supervise others
`Supervisor`s (see *Supervision Trees* below).

The `Concurrent::Supervisor` class is a faithful and nearly complete implementaion
of Erlang's Supervisor module. 

## Basic Supervisor Behavior

At the core a `Supervisor` instance is a very simple object. Simply create a `Supervisor`,
add at least one worker using the `#add_worker` method, and start the `Supervisor` using
either `#run` (blocking) or `#run!` (non-blocking). The `Supervisor` will spawn a new thread
for each child and start the chid on its thread. The `Supervisor` will then continuously
monitor all its child threads. If any of the children crash the `Supervisor` will restart
them in accordance with its *restart strategy* (see below). Later, stop the `Supervisor`
with its `#stop` method and it will gracefully stop all its children.

A `Supervisor` will also track the number of times it must restart children withing a
defined, sliding window of time. If the onfigured threshholds are exceeded (see *Intervals*
below) then the `Supervisor` will assume there is a catastrophic failure (possibly within
the `Supervisor` itself) and it will shut itself down. If the `Supervisor` is part of a
*supervision tree* (see below) then its `Supervisor` will likely restart it.

```ruby
task = Concurrent::TimerTask.new{ print "[#{Time.now}] Hello world!\n" }

supervisor = Concurrent::Supervisor.new
supervisor.add_worker(task)

supervisor.run! # the #run method blocks, #run! does not
```

## Workers

Any object can be managed by a `Supervisor` so long as the class to be supervised supports
the required API. A supervised object needs only support three methods:

* `#run` is a blocking call that starts the child then blocks until the child is stopped
* `#running?` is a predicate method indicating whether or not the child is running
* `#stop` gracefully stops the child if it is running

### Runnable

To facilitate the creation of supervisorable classes, the `Runnable` module is provided.
Simple include `Runnable` in the class and the required API methods will be provided.
`Runnable` also provides several lifecycle methods that may be overridden by the including
class. At a minimum the `#on_task` method *must* be overridden. `Runnable` will provide an
infinite loop that will start when either the `#run` or `#run!` method is called. The subclass
`#on_task` method will be called once in every iteration. The overridden method should provide
some sort of blocking behavior otherwise the run loop may monopolize the processor and spike
the processor utilization.

The following optional lifecycle methods are also provided:

* `#on_run` is called once when the object is started via the `#run` or `#run!` method but before the `#on_task` method is first called
* `#on_stop` is called once when the `#stop` method is called, after the last call to `#on_task`

```ruby
class Echo
  include Concurrent::Runnable

  def initialize
    @queue = Queue.new
  end

  def post(message)
    @queue.push(message)
  end

  protected

  def on_task
    message = @queue.pop
    print "#{message}\n"
  end
end

echo = Echo.new
supervisor = Concurrent::Supervisor.new
supervisor.add_worker(echo)
supervisor.run!
```

##  Supervisor Configuration

A newly-created `Supervisor` will be configured with a reasonable set of options that should
suffice for most purposes. In many cases no additional configuration will be required. When
more granular control is required a `Supervisor` may be given several configuration options
during initialization. Additionally, a few per-worker configuration options may be passed
during the call to `#add_worker`. Once a `Supervisor` is created and the workers are added
no additional configuration is possible.

### Intervals

A `Supervisor` monitors its children and conducts triage operations based on several configurable
intervals:

* `:monitor_interval` specifies the number of seconds between health checks of the workers. The
  higher the interval the longer a particular worker may be dead before being restarted. The
  default is 1 second.
* `:max_restart` specifies the number of times (in total) the `Supevisor` may restart children
  before it assumes there is a catastrophic failure and it shuts itself down. The default is 5
  restarts.
* `:max_time` if the time interval over which `#max_restart` is tracked. Since `Supervisor` is
  intended to be used in applications that may run forever the `#max_restart` count must be
  timeboxed to prevent erroneous `Supervisor shutdown`. The default is 60 seconds.

### Restart Strategy

When a child thread dies the `Supervisor` will restart it, and possibly other children,
with the expectation that the workers are capable of cleaning themselves up and running
again. The `Supervisor` will call each targetted worker's `#stop` method, kill the
worker's thread, spawn a new thread, and call the worker's `#run` method.

* `:one_for_one` When this restart strategy is set the `Supervisor` will only restart
  the worker thread that has died. It will not restart any of the other children.
  This is the default restart strategy.
* `:one_for_all` When this restart strategy is set the `Supervisor` will restart all
  children when any one child dies. All workers will be stopped in the order they were
  originally added to the `Supervisor`. Once all childrean have been stopped they will
  all be started again in the same order.
* `:rest_for_one` This restart strategy assumes that the order the workers were added
  to the `Supervisor` is meaningful. When one child dies all the downstream children
  (children added to the `Supervisor` after the dead worker) will be restarted. The
  `Supervisor` will begin by calling the `#stop` method on the dead worker and all
  downstream workers. The `Supervisor` will then iterate over all dead workers and
  restart each by creating a new thread then calling the worker's `#run` method.

When a restart is initiated under any strategy other than `:one_for_one` the
`:max_restart` value will only be incremented by one, regardless of how many children
are restarted.

### Worker Restart Option

When a worker dies the default behavior of the `Supervisor` is to restart one or more
workers according to the restart strategy defined when the `Supervisor` is created
(see above). This behavior can be modified on a per-worker basis using the `:restart`
option when calling `#add_worker`. Three worker `:restart` options are supported:

* `:permanent` means the worker is intended to run forever and will always be restarted
  (this is the default)
* `:temporary` workers are expected to stop on their own as a normal part of their operation
  and will only be restarted on an abnormal exit
* `:transient` workers will never be restarted

### Worker Type

Every worker added to a `Supervisor` is of either type `:worker` or `:supervisor`. The defauly
value is `:worker`. Currently this type makes no functional difference. It is purely informational.

## Supervision Trees

One of the most powerful aspects of Erlang's supervisor module is its ability to supervise
other supervisors. This allows for the creation of deep, robust *supervision trees*.
Workers can be gouped under multiple bottom-level `Supervisor`s. Each of these `Supervisor`s
can be configured according to the needs of its workers. These multiple `Supervisor`s can
be added as children to another `Supervisor`. The root `Supervisor` can then start the
entire tree via trickel-down (start its children which start their children and so on).
The root `Supervisor` then monitor its child `Supervisor`s, and so on.

Supervision trees are the main reason that a `Supervisor` will shut itself down if its
`:max_restart`/`:max_time` threshhold is exceeded. An isolated `Supervisor` will simply
shut down forever. A `Supervisor` that is part of a supervision tree will shut itself
down and let its parent `Supervisor` manage the restart.

## Examples

```ruby
QUERIES = %w[YAHOO Microsoft google]

class FinanceActor < Concurrent::Actor
  def act(query)
    finance = Finance.new(query)
    print "[#{Time.now}] RECEIVED '#{query}' to #{self} returned #{finance.update.suggested_symbols}\n\n"
  end
end

financial, pool = FinanceActor.pool(5)

timer_proc = proc do
  query = QUERIES[rand(QUERIES.length)]
  financial.post(query)
  print "[#{Time.now}] SENT '#{query}' from #{self} to worker pool\n\n"
end

t1 = Concurrent::TimerTask.new(execution_interval: rand(5)+1, &timer_proc)
t2 = Concurrent::TimerTask.new(execution_interval: rand(5)+1, &timer_proc)

overlord = Concurrent::Supervisor.new

overlord.add_worker(t1)
overlord.add_worker(t2)
pool.each{|actor| overlord.add_worker(actor)}

overlord.run!
```

## Additional Reading

* [Supervisor Module](http://www.erlang.org/doc/man/supervisor.html)
* [Supervisor Behaviour](http://www.erlang.org/doc/design_principles/sup_princ.html)
* [Who Supervises The Supervisors?](http://learnyousomeerlang.com/supervisors)
* [OTP Design Principles](http://www.erlang.org/doc/design_principles/des_princ.html)

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
