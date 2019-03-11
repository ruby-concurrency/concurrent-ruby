# Final report

Since the midterm report I have continued working on the project until 8. February as planned.
The remaining half of the time I was focusing on implementing actors 
which would precisely match behaviour of Erlang actors.
The Erlang compatible implementation was chosen for two reasons. 
First reason was to make porting of the Erlang's
[OTP](https://learnyousomeerlang.com/what-is-otp) library possible.
OTP is time proven library and even a philosophy how to write reliable concurrent applications. 
Second reason was 
that there is an intersection between Ruby and Elixir programmers.
Elixir runs on Erlang's VM and the programmers are familiar with OTP,
therefore they will be able to reuse their knowledge in Ruby.    
    
## Erlang actors

The actor implementation matches the Erlang's implementation.
Mainly it has the same: 
*   exit behavior (called termination in Ruby to avoid collision with `Kernel#exit`),
*   ability to link and monitor actors, 
*   ability to have much more actors then threads,
*   ordering guarantees between messages and signals,
*   message receiving features.

The actors can be written in 2 modes. First will require it's own thread, 
second will run on a thread pool. 
Please see 
[Actor types section](http://blog.pitr.ch/concurrent-ruby/master/Concurrent/ErlangActor.html)
for more details.

Especially ordering guarantees are not easy to get correct. 
As an example lets have a look at the reasoning behind implementation of monitoring. 
Understanding of the monitors in Erlang actors is necessary for the following part.

When `#monitor` is called in actor A it sends a Monitor signal to actor B.
The actor B will then send a Down signal to A when it terminates.
Actor is not processing any messages or signals when after it terminates.
Therefore the monitor method needs to also check if B terminated.

Lets reason about the ordering between sending the signal Monitor and checking termination of B.
If A first checks termination of B sending Monitor signal only if B is not terminated
then A can never get a reply if B terminates after A checks its termination and before A sends Monitor signal.
Therefore A needs to first optimistically send a Monitor signal and then check if B terminated.
If B already terminated then we do not expect it to send a Down signal, 
instead the `#monitor` places Down message with reason NoActor immediately into A's mailbox.

We will now move our focus to B considering the case when A send the signal
and the termination check of B was false.
The normal case is that B gets the Monitor signal and processes it 
remembering it is monitored.
Then on termination B sends a Down signal with the reason for termination to A.
The more interesting case is when the actor B gets the Monitor signal into its mailbox
but it is terminated before it can process it. 
In that case,
since we know that A did no see B terminated,
we have to process the Monitor signal even if terminated and send a corresponding Down signal to A.
Therefore the B actor termination does two main operations in the following order:
it resolves its termination future (terminates) which is used by A in monitor to do the check,
it drains its mailbox looking for signals which have to be replied to.
The mailbox draining has to happen after termination is resolved 
otherwise it could happen before A sends its Monitor signal which could then go unanswered.
    
    B drains > A sends Monitor signal > A termination check false > B terminates
    # the Monitor signal is never processed by B

Therefore we have concluded that A has send the monitor signal first 
then check B's termination and B has to terminate first 
(resolve its termination future) then drain signals from mailbox.
With this ordering following cases can happen:

    A sends Monitor signal > A termination check false > B terminates > B drains and replies    
    A sends Monitor signal > B terminates > A termination check true therefore A places Down itself
    B terminates > A sends Monitor signal > A termination check true therefore A places Down itself    

Where in each case A gets the Down message.

There is one last problem which could happen, 
the Down message could be received twice by A.
It could happen in the last two sequences 
where A detects B's termination 
and where we did not consider B's drain for simplicity.
The last two sequences should actually be: 
 
    A sends Monitor signal > B terminates > A termination check true therefore A places Down itself > B drains and replies
    B terminates > A sends Monitor signal > A termination check true therefore A places Down itself > B drains and replies    
    A sends Monitor signal > B terminates > B drains and replies > A termination check true therefore A places Down itself 
    B terminates > A sends Monitor signal > B drains and replies > A termination check true therefore A places Down itself     
    B terminates > B drains > A sends Monitor signal > A termination check true therefore A places Down itself     
   
In the first four orderings the drain is happening after monitor call sends Monitor signal in A
therefore the draining will send Down signal 
because it cannot know if A send itself Down message about B's termination.
The A actor has to prevent the duplication.
In its state it stores an information about the active monitors (set by the `#monitor`),
when a Down message arrives it is deleted
therefore any subsequent Down messages are ignored.
Both monitor call in A and the draining in B sends Down signal with a NoActor reason
so it does not matter which arrives first.

This was a reasoning for the actor monitoring implementation. 
Other actor features like linking, demonitoring, etc. required similar approach.

The abstraction is ready for release. 
For more details about usage see the API documentation 
<http://blog.pitr.ch/concurrent-ruby/master/Concurrent/ErlangActor.html>.

## Integration

Integration of concurrency abstractions was a motivation of the project.
I've added Promises library to the concurrent-ruby in the past
which can represent future computations and values 
and therefore can be used as a connecting element between abstractions.

```ruby
an_actor.ask_op(:payload).then_flat { |reply| a_channel.push_op reply }
```

In the example above an actor is asked with a payload, 
which is represented as a Future object. 
When the Future is resolved with a reply 
it executes the block with the reply argument
usually defined by `then` method.
In this case `then_flat` needs to be used
because we want a Future representing the value of the inner push operation 
pushing the reply into a channel.
All the operations in this example are done asynchronously on a thread pool.

Usual direct thread blocking mode is also always supported. 
The following example does the same but uses the current Thread to do the work. 

```ruby
reply = an_actor.ask(:payload) # blocks until it replies
a_channel.push reply # blocks if there is no space in the channel. 
```

In addition all blocking operations support timeouts, 
since it is a good practice to give each blocking operation a timeout 
and try to recover if it takes too long.
It usually prevents the whole application from hitting a deadlock, 
or at least it can give developer idea what is going wrong 
if timeouts are logged.

Promises are also used instead of state flags.
So for example termination of actor is not implemented as simple `#terminated? #=> true or false` method
but `#terminated` returns a future which is resolved when the Actor terminates.
More over if it is fulfilled it means actor terminated normally with a `actor.terminated.value`
and when it is rejected it means that the actor terminated abnormally because of `actor.terminated.reason`.
That again allows to integrate with other abstractions, e.g.

```ruby
actor.terminated.value! # block current thread until actor terminates or raise reason if any
actor.terminated.then(actor) { |value, actor| a_logger.debug "#{actor} terminated with #{value}" }
```    
   
Besides chaining and connecting abstractions together,
concurrency level of all abstractions executing tasks can be manages with the Throttle abstraction.

```ruby
throttle = Concurrent::Throttle.new 10
1000.times do
  Thread.new do
    actor = Concurrent::ErlangActor.spawn_actor type: :on_pool, executor: throttle.on(:io) do
      receive(keep: true) { |m| reply m }  
    end
    actor.ask :ping 
    Concurrent::Promises.future_on(throttle.on(:fast)) { 1 + 1 }.then(&:succ)
  end
end
```

In the example above the throttle ensures that
there is at most 10 actors or futures processing message or executing their bodies.
Notice that this works not only across abstractions but also across thread pools.
The actor is running on the global thread pool for blocking operations - `:io`
and the futures are executing on the global thread poll for `:fast` non-blocking operations.

This is of course not an exhaustive list of possible ways how the abstractions can be integrated
but rather few examples to give a feeling what is possible.
Please also see an executable 
[example](http://blog.pitr.ch/concurrent-ruby/master/file.medium-example.out.html)
using the integrations.

## What was not finished

The original proposal also contained a work steeling thread pool 
which would improve performance of small non-blocking tasks.
It would not provide any new functionality to the users. 
Therefore for lack of time I decided to postpone this for some later time. 

## Release

All the work done during the project is released in `concurrent-ruby-edge` version 0.5.0 to Ruby users. 
After some time when feedback is gathered the abstractions will be released in the stable core - `concurrent-ruby`.
This is necessary because anything released in the core has to stay backward compatible,
therefore it would prevent even minor improvements to the API.
No big changes to the APIs are expected.

## After the project

During the project it become apparent that there will not be much time left 
to focus on propagation of the new abstractions. 
I've rather decided to focus on the abstraction development  
and completion of all their API documentation.

I plan to turn my attention 
to letting Ruby community know about the project and the new features after the project ends.
I will record four introductory videos for each abstraction, 
since it appears to me that it become a better platform to reach wider audience then writing blog posts.
