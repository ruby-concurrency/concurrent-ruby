A mixin module that provides simple asynchronous behavior to any standard
class/object or object. 

```cucumber
Feature:
  As a stateful, plain old Ruby class/object
  I want safe, asynchronous behavior
  So my long-running methods don't block the main thread
```

Stateful, mutable objects must be managed carefully when used asynchronously.
But Ruby is an object-oriented language so designing with objects and classes
plays to Ruby's strengths and is often more natural to many Ruby programmers.
The `Async` module is a way to mix simple yet powerful asynchronous capabilities
into any plain old Ruby object or class. These capabilities provide a reasonable
level of thread safe guarantees when used correctly.

When this module is mixed into a class or object it provides to new methods:
`async` and `await`. These methods are thread safe with respect to the enclosing
object. The former method allows methods to be called asynchronously by posting
to the global thread pool. The latter allows a method to be called synchronously
on the current thread but does so safely with respect to any pending asynchronous
method calls. Both methods return an `Obligation` which can be inspected for
the result of the method call. Calling a method with `async` will return a
`:pending` `Obligation` whereas `await` will return a `:complete` `Obligation`.

Very loosely based on the `async` and `await` keywords in C#.

#### An Important Note About Initialization

> This module depends on several internal synchronization objects that
> must be initialized prior to calling any of the async/await/executor methods.
> The best practice is to call `init_mutex` from within the constructor
> of the including class. A less ideal but acceptable practice is for the
> thread creating the asynchronous object to explicitly call the `init_mutex`
> method prior to calling any of the async/await/executor methods. If
> `init_mutex` is *not* called explicitly the async/await/executor methods
> will raise a `Concurrent::InitializationError`. This is the only way 
> thread-safe initialization can be guaranteed.

#### An Important Note About Thread Safe Guarantees

> Thread safe guarantees can only be made when asynchronous method calls
> are not mixed with synchronous method calls. Use only synchronous calls
> when the object is used exclusively on a single thread. Use only
> `async` and `await` when the object is shared between threads. Once you
> call a method using `async`, you should no longer call any methods
> directly on the object. Use `async` and `await` exclusively from then on.
> With careful programming it is possible to switch back and forth but it's
> also very easy to create race conditions and break your application.
> Basically, it's "async all the way down."

### Examples

#### Defining an asynchronous class

```cucumber
Scenario: Defining an asynchronous class
  Given a class definition
  When I include the Concurrent::Async module
  Then an `async` method is defined for all objects of the class
  And an `await` method is defined for all objects of the class

Scenario: Calling the `async` method
  Given a class which includes Concurrent::Async module
  When I call a normal method through the `async` delegate method
  Then the method returns a Concurrent::Future object
  And the method is executed on a background thread using the global thread pool
  And the current thread does not block
  And thread safety is provided with respect to other `async` and `await` calls
  And the returned future can be interrogated for the status of the method call
  And the returned future will eventually contain the `value` of the method call
  Or the returned future will eventually contain the `reason` the method call failed

Scenario: Calling the `await` method
  Given a class which includes Concurrent::Async module
  When I call a normal method through the `await` delegate method
  Then the method returns a Concurrent::IVar object
  And the method is executed on the current thread
  And thread safety is provided with respect to other `async` and `await` calls
  And the returned ivar will be in the :fulfilled state
  Or the returned ivar will be in the :rejected state
  And the returned ivar will immediately contain the `value` of the method call
  Or the returned ivar will immediately contain the `reason` the method call failed
```

```ruby
class Echo
  include Concurrent::Async

  def initialize
    init_mutex # initialize the internal synchronization objects
  end

  def echo(msg)
    sleep(rand)
    print "#{msg}\n"
    nil
  end
end

horn = Echo.new
horn.echo('zero') # synchronous, not thread-safe

horn.async.echo('one') # asynchronous, non-blocking, thread-safe
horn.await.echo('two') # synchronous, blocking, thread-safe
```

#### Monkey-patching an existing object

```cucumber
Scenario: Monkey-patching an existing object
  Given an object of a class that does not include the Concurrent::Async module
  When I extend the object with the Concurrent::Async module
  Then an `async` method is monkey-patched onto the object
  And an `await` method is monkey-patched onto the object
  And the object behaved as though Concurrent::Async were included in the class
  And the `async` and `await` methods perform as expected
  And no other objects of that class are affected
```

```ruby
numbers = 1_000_000.times.collect{ rand }
numbers.extend(Concurrent::Async)
numbers.init_mutex # initialize the internal synchronization objects
  
future = numbers.async.max
future.state #=> :pending
  
sleep(2)
  
future.state #=> :fulfilled
future.value #=> 0.999999138918843
```
