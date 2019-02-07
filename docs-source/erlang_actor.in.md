## Examples

The simplest example is to use the actor as an asynchronous execution.
Although, `Promises.future { 1 + 1 }` is better suited for that purpose.

```ruby
actor = Concurrent::ErlangActor.spawn(:on_thread, name: 'addition') { 1 + 1 }
actor.terminated.value!
```

Let's send some messages and maintain some internal state 
which is what actors are good for.

```ruby
actor = Concurrent::ErlangActor.spawn(:on_thread, name: 'sum') do
  sum = 0 # internal state
  # receive and sum the messages until the actor gets :done
  while true
    message = receive
    break if message == :done
    # if the message is asked and not only told, 
    # reply with a current sum
    reply sum += message   
  end
  sum
end
```

The actor can be either told a message asynchronously, 
or asked. The ask method will block until actor replies.

```ruby
# tell returns immediately returning the actor 
actor.tell(1).tell(1)
# blocks, waiting for the answer 
actor.ask 10
# stop the actor
actor.tell :done
actor.terminated.value!
```

### Receiving

Simplest message receive.

```ruby
actor = Concurrent::ErlangActor.spawn(:on_thread) { receive }
actor.tell :m
actor.terminated.value!
```

which also works for actor on pool, 
because if no block is given it will use a default block `{ |v| v }` 

```ruby
actor = Concurrent::ErlangActor.spawn(:on_pool) { receive { |v| v } }
# can simply be following
actor = Concurrent::ErlangActor.spawn(:on_pool) { receive }
actor.tell :m
actor.terminated.value!
```

TBA

### Actor types

There are two types of actors. 
The type is specified when calling spawn as a first argument, 
`Concurrent::ErlangActor.spawn(:on_thread, ...` or 
`Concurrent::ErlangActor.spawn(:on_pool, ...`.

The main difference is in how receive method returns.
 
-   `:on_thread` it blocks the thread until message is available, 
    then it returns or calls the provided block first. 
 
-   However, `:on_pool` it has to free up the thread on the receive 
    call back to the pool. Therefore the call to receive ends the 
    execution of current scope. The receive has to be given block
    or blocks that act as a continuations and are called 
    when there is message available.
 
Let's have a look at how the bodies of actors differ between the types:

```ruby
ping = Concurrent::ErlangActor.spawn(:on_thread) { reply receive }
ping.ask 42
```

It first calls receive, which blocks the thread of the actor. 
When it returns the received message is passed an an argument to reply,
which replies the same value back to the ask method. 
Then the actor terminates normally, because there is nothing else to do.

However when running on pool a block with code which should be evaluated 
after the message is received has to be provided. 

```ruby
ping = Concurrent::ErlangActor.spawn(:on_pool) { receive { |m| reply m } }
ping.ask 42
```

It starts by calling receive which will remember the given block for later
execution when a message is available and stops executing the current scope.
Later when a message becomes available the previously provided block is given
the message and called. The result of the block is the final value of the 
normally terminated actor.

The direct blocking style of `:on_thread` is simpler to write and more straight
forward however it has limitations. Each `:on_thread` actor creates a Thread 
taking time and resources. 
There is also a limited number of threads the Ruby process can create 
so you may hit the limit and fail to create more threads and therefore actors.  

Since the `:on_pool` actor runs on a poll of threads, its creations 
is faster and cheaper and it does not create new threads. 
Therefore there is no limit (only RAM) on how many actors can be created.

To simplify, if you need only few actors `:on_thread` is fine. 
However if you will be creating hundreds of actors or 
they will be short-lived `:on_pool` should be used.      

### Erlang behaviour

The actor matches Erlang processes in behaviour. 
Therefore it supports the usual Erlang actor linking, monitoring, exit behaviour, etc.

```ruby
actor = Concurrent::ErlangActor.spawn(:on_thread) do
  spawn(link: true) do # equivalent of spawn_link in Erlang
    terminate :err # equivalent of exit in Erlang    
  end
  trap # equivalent of process_flag(trap_exit, true) 
  receive  
end
actor.terminated.value!
```

### TODO

*   receives
*   More erlang behaviour examples
*   Back pressure with bounded mailbox
*   _op methods
*   types of actors
