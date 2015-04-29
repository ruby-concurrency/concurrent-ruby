`Synchronization` module provides common layer for synchronization. It provides same guaranties independent of any particular Ruby implementation.

*This is a new module, it is expected to fully stabilize for 1.0 release.*

## Synchronization::Object

Provides common parent for all objects which need to be synchronized or be using other synchronization tools. It provides:

-   Synchronized block
-   Methods for waiting and signaling 
-   Volatile fields
-   Ensure visibility of final fields
-   Fields with CAS operations

## Synchronized block

`Synchronization::Object` provides private method `#synchronize(&block)`. For a given object only one Thread can enter one of the blocks synchronized against this object. Object is locked when a thread enters one of the synchronized blocks.

Example of a simple counter which can be used by multiple threads:

```ruby
class SafeCounter < Concurrent::Synchronization::Object
  def initialize
    super
    synchronize { @count = 0 }
  end

  def increment
    synchronize { @count += 1 }
  end

  def count
    synchronize { @count }
  end
end
```

### Naming conventions

Methods starting with `ns_` are marking methods that are not using synchronization by themselves, they have to be used inside synchronize block. They are usually used in pairs to separate the synchronization from behavior:

```ruby
def compute
  service.report synchronize { ns_compute }
end

private

def ns_compute
  ns_compute_reduce ns_compute_map
end
``` 
where `compute` defines how is it synchronized and `ns_compute` handles the behavior (in this case the computation). `ns_` methods should only call other `ns_` methods or `pr_` methods. They can call normal methods on other objects, but that should be done with care (better to avoid) because the thread escapes this object while the lock is still held, which can lead to deadlock. That's why the `report` method is called in `compute` and not in `ns_compute`.

`pr_` methods are pure functions they can be used in and outside of synchronized blocks.

## Methods for waiting and signaling

Sometimes while already inside the synchronized block some condition is not met. Then the thread needs to wait (releasing the lock) until the condition is met. The waiting thread is then signaled that it can continue.

To fulfill these needs there are private methods:

-   `ns_wait` {include:Concurrent::Synchronization::AbstractObject#ns_wait}
-   `ns_wait_until` {include:Concurrent::Synchronization::AbstractObject#ns_wait_until}
-   `ns_signal` {include:Concurrent::Synchronization::AbstractObject#ns_signal}
-   `ns_broadcast` {include:Concurrent::Synchronization::AbstractObject#ns_broadcast}

All methods have to be called inside synchronized block.

## Volatile fields

`Synchronization::Object` can have volatile fields (Java semantic). They are defined by `attr_volatile :field_name`. `attr_volatile` defines reader and writer with the `field_name`. Any write is always immediately visible for any subsequent reads of the same field. 

## Ensure visibility of final fields

Instance variables assigned only once in `initialize` method are not guaranteed to be visible to all threads. For that user can call `ensure_ivar_visibility!` method, like in following example taken from `Edge::AbstractPromise` implementation:

```ruby
class AbstractPromise < Synchronization::Object
  def initialize(future, *args, &block)
    super(*args, &block)
    @Future = future
    ensure_ivar_visibility!
  end
  # ...
end  
```

###  Naming conventions

Instance variables with camel case names are final and never reassigned.

## Fields with CAS operations

They are not supported directly, but AtomicReference can be stored in final field and then CAS operations can be done on it, like in following example taken from `Edge::Event` implementation:

```ruby
class Event < Synchronization::Object
  extend FutureShortcuts

  def initialize(promise, default_executor = :io)
    @Promise         = promise
    @DefaultExecutor = default_executor
    @Touched         = AtomicBoolean.new(false)
    super()
    ensure_ivar_visibility!
  end
  # ...
  def touch
    # distribute touch to promise only once
    @Promise.touch if @Touched.make_true
    self
  end
  # ...
end  
```

## Memory model (sort of)

// TODO

