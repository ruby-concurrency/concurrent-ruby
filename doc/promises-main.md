# Description

Promises is a new framework unifying former `Concurrent::Future`,
`Concurrent::Promise`, `Concurrent::IVar`, `Concurrent::Event`,
`Concurrent.dataflow`, `Delay`, `TimerTask` . It extensively uses the new
synchronization layer to make all the methods *lock-free* (with the exception
of obviously blocking operations like `#wait`, `#value`, etc.). As a result it
lowers a danger of deadlocking and offers better performance.

It provides tools as other promise libraries, users coming from other languages
and other promise libraries will find the same tools here (probably named
differently though). The naming convention borrows heavily from JS promises.
  
This framework however is not just a re-implementation of other promise
library, it takes inspiration from many other promise libraries, adds new
ideas, and integrates with other abstractions like actors and channels.
Therefore it is much more likely that user fill find a suitable solution for
his problem in this library, or if needed he will be able to combine parts
which were designed to work together well (rather than having to combine
fragilely independent tools).

> *Note:* The channel and actor integration is younger and will stay in edge for
> a little longer than core promises.

> *TODO*
>
> -   What is it?
> -   What is it for?
> -   Main classes {Future}, {Event}
> -   Explain pool usage :io vs :fast, and `_on` `_using` suffixes.
> -   Why is this better than other solutions, integration actors and channels

# Main classes

The main public user-facing classes are {Concurrent::Promises::Event} and
{Concurrent::Promises::Future} which share common ancestor
{Concurrent::Promises::AbstractEventFuture}.

**Event:** 
> {include:Concurrent::Promises::Event}

**Future:** 
> {include:Concurrent::Promises::Future}

