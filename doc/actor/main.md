# Actor model

-  Light-weighted.
-  Inspired by Akka and Erlang.
-  Modular.

Actors are sharing a thread-pool by default which makes them very cheap to create and discard.
Thousands of actors can be created, allowing you to break the program into small maintainable pieces,
without violating the single responsibility principle.

## What is an actor model?

[Wiki](http://en.wikipedia.org/wiki/Actor_model) says:
The actor model in computer science is a mathematical model of concurrent computation
that treats _actors_ as the universal primitives of concurrent digital computation:
in response to a message that it receives, an actor can make local decisions,
create more actors, send more messages, and determine how to respond to the next
message received.

## Why?

Concurrency is hard this is one of many ways how to simplify the problem.
It is simpler to reason about actors than about locks (and all their possible states).

## How to use it

An example:

```ruby
class Counter < Concurrent::Actor::Context
  # Include context of an actor which gives this class access to reference
  # and other information about the actor

  # use initialize as you wish
  def initialize(initial_value)
    @count = initial_value
  end

  # override on_message to define actor's behaviour
  def on_message(message)
    if Integer === message
      @count += message
    end
  end
end #

# Create new actor naming the instance 'first'.
# Return value is a reference to the actor, the actual actor is never returned.
counter = Counter.spawn(:first, 5)

# Tell a message and forget returning self.
counter.tell(1)
counter << 1
# (First counter now contains 7.)

# Send a messages asking for a result.
counter.ask(0).class
counter.ask(0).value
```

{include:file:doc/actor/quick.out.rb}

## Messaging

Messages are processed in same order as they are sent by a sender. It may interleaved with
messages form other senders though. There is also a contract in actor model that
messages sent between actors should be immutable. Gems like

- [Algebrick](https://github.com/pitr-ch/algebrick) - Typed struct on steroids based on
  algebraic types and pattern matching
- [Hamster](https://github.com/hamstergem/hamster) - Efficient, Immutable, Thread-Safe
  Collection classes for Ruby

are very useful.

### Dead letter routing

see {AbstractContext#dead_letter_routing} description:

> {include:Actor::AbstractContext#dead_letter_routing}

## Architecture

Actors are running on shared thread poll which allows user to create many actors cheaply.
Downside is that these actors cannot be directly used to do IO or other blocking operations.
Blocking operations could starve the `default_task_pool`. However there are two options:

- Create an regular actor which will schedule blocking operations in `global_operation_pool`
  (which is intended for blocking operations) sending results back to self in messages.
- Create an actor using `global_operation_pool` instead of `global_task_pool`, e.g.
  `AnIOActor.spawn name: :blocking, executor: Concurrent.configuration.global_operation_pool`.

Each actor is composed from 4 parts:

### {Reference}
{include:Actor::Reference}

### {Core}
{include:Actor::Core}

### {AbstractContext}
{include:Actor::AbstractContext}

### {Behaviour}
{include:Actor::Behaviour}

## Speed

Simple benchmark Actor vs Celluloid, the numbers are looking good
but you know how it is with benchmarks. Source code is in
`examples/actor/celluloid_benchmark.rb`. It sends numbers between x actors
and adding 1 until certain limit is reached.

Benchmark legend:

- mes.  - number of messages send between the actors
- act.  - number of actors exchanging the messages
- impl. - which gem is used

### JRUBY

    Rehearsal --------------------------------------------------------
    50000    2 concurrent 24.110000   0.800000  24.910000 (  7.728000)
    50000    2 celluloid  28.510000   4.780000  33.290000 ( 14.782000)
    50000  500 concurrent 13.700000   0.280000  13.980000 (  4.307000)
    50000  500 celluloid  14.520000  11.740000  26.260000 ( 12.258000)
    50000 1000 concurrent 10.890000   0.220000  11.110000 (  3.760000)
    50000 1000 celluloid  15.600000  21.690000  37.290000 ( 18.512000)
    50000 1500 concurrent 10.580000   0.270000  10.850000 (  3.646000)
    50000 1500 celluloid  14.490000  29.790000  44.280000 ( 26.043000)
    --------------------------------------------- total: 201.970000sec
    
     mes. act.      impl.      user     system      total        real
    50000    2 concurrent  9.820000   0.510000  10.330000 (  5.735000)
    50000    2 celluloid  10.390000   4.030000  14.420000 (  7.494000)
    50000  500 concurrent  9.880000   0.200000  10.080000 (  3.310000)
    50000  500 celluloid  12.430000  11.310000  23.740000 ( 11.727000)
    50000 1000 concurrent 10.590000   0.190000  10.780000 (  4.029000)
    50000 1000 celluloid  14.950000  23.260000  38.210000 ( 20.841000)
    50000 1500 concurrent 10.710000   0.250000  10.960000 (  3.892000)
    50000 1500 celluloid  13.280000  30.030000  43.310000 ( 24.620000) (1)

### MRI 2.1.0

    Rehearsal --------------------------------------------------------
    50000    2 concurrent  4.640000   0.080000   4.720000 (  4.852390)
    50000    2 celluloid   6.110000   2.300000   8.410000 (  7.898069)
    50000  500 concurrent  6.260000   2.210000   8.470000 (  7.400573)
    50000  500 celluloid  10.250000   4.930000  15.180000 ( 14.174329)
    50000 1000 concurrent  6.300000   1.860000   8.160000 (  7.303162)
    50000 1000 celluloid  12.300000   7.090000  19.390000 ( 17.962621)
    50000 1500 concurrent  7.410000   2.610000  10.020000 (  8.887396)
    50000 1500 celluloid  14.850000  10.690000  25.540000 ( 24.489796)
    ---------------------------------------------- total: 99.890000sec
    
     mes. act.      impl.      user     system      total        real
    50000    2 concurrent  4.190000   0.070000   4.260000 (  4.306386)
    50000    2 celluloid   6.490000   2.210000   8.700000 (  8.280051)
    50000  500 concurrent  7.060000   2.520000   9.580000 (  8.518707)
    50000  500 celluloid  10.550000   4.980000  15.530000 ( 14.699962)
    50000 1000 concurrent  6.440000   1.870000   8.310000 (  7.571059)
    50000 1000 celluloid  12.340000   7.510000  19.850000 ( 18.793591)
    50000 1500 concurrent  6.720000   2.160000   8.880000 (  7.929630)
    50000 1500 celluloid  14.140000  10.130000  24.270000 ( 22.775288) (1)

*Note (1):* Celluloid is using thread per actor so this bench is creating about 1500
native threads. Actor is using constant number of threads.
