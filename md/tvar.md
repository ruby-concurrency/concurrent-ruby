# TVars

`TVar` and `atomically` implement a transactional memory. A `TVar` is a single
item container that always contains exactly one value. The `atomically` method
allows you to modify a set of `TVar` objects with the guarantee that all of the
updates are collectively atomic - they either all happen or none of them do -
consistent - a `TVar` will never enter an illegal state - and isolated - atomic
blocks never interfere with each other when they are running. You may recognise
these properties from database transactions.

There are some very important and unusual semantics that you must be aware of:

*   Most importantly, the block that you pass to `atomically` may be executed more
than once. In most cases your code should be free of side-effects, except for
via `TVar`.

*   If an exception escapes an `atomically` block it will abort the transaction.

*   It is undefined behaviour to use `callcc` or `Fiber` with `atomically`.

*   If you create a new thread within an `atomically`, it will not be part of
the transaction. Creating a thread counts as a side-effect.

We implement nested transactions by flattening.

We only support strong isolation if you use the API correctly. In order words,
we do not support strong isolation.

See:

1.  T. Harris, J. Larus, and R. Rajwar. Transactional Memory. Morgan & Claypool, second edition, 2010.

## Motivation

Consider an application that transfers money between bank accounts. We want to
transfer money from one account to another. It is very important that we don't
lose any money! But it is also important that we can handle many account
transfers at the same time, so we run them concurrently, and probably also in
parallel.

This code shows us transferring ten pounds from one account to another.

```ruby
a = new BankAccount(100_000)
b = new BankAccount(100)

a.value -= 10
b.value += 10
```

Before we even start to talk about to talk about concurrency and parallelism, is
this code safe? What happens if after removing money from account a, we get an
exception? It's a slightly contrived example, but if the account totals were
very large, adding to them could involve the stack allocation of a `BigNum`, and
so could cause out of memory exceptions.  In that case the money would have
disappeared from account a, but not appeared in account b. Disaster!

So what do we really need to do?

```ruby
a = new BankAccount(100_000)
b = new BankAccount(100)

original_a = a.value
a.value -= 10

begin
  b.value += 10
rescue e =>
  a.value = original_a
  raise e
end
```

This rescues any exceptions raised when setting b and will roll back the change
we have already made to b. We'll keep this rescue code in mind, but we'll leave
it out of future examples for simplicity.

That might have made the code work when it only runs sequentially. Lets start to
consider some concurrency. It's obvious that we want to make the transfer of
money mutually exclusive with any other transfers - in order words it is a
critical section.

The usual solution to this would be to use a lock.

```ruby
lock.synchronize do
  a.value -= 10
  b.value += 10
end
```

That should work. Except we said we'd like these transfer to run concurrently,
and in parallel. With a single lock like that we'll only let one transfer take
place at a time. Perhaps we need more locks? We could have one per account

```ruby
a.lock.synchronize do
  b.lock.synchronize do
    a.value -= 10
    b.value += 10
  end
end
```

However this is vulnerable to deadlock. If we tried to transfer from a to b, at
the same time as from b to a, it's possible that the first transfer locks a, the
second transfer locks b, and then they both sit there waiting forever to get the
other lock. Perhaps we can solve that by applying a total ordering to the locks
- always acquire them in the same order?

```ruby
locks_needed = [a.lock, b.lock]
locks_in_order = locks_needed.sort{ |x, y| x.number <=> y.number }

locks_in_order[0].synchronize do
  locks_in_order[1].synchronize do
    a.value -= 10
    b.value += 10
  end
end
```

That might work. But we need to know exactly what locks we're going to need
before we start. If there were conditions in side the transfer this might be
more complicated. We also need to remember the rescue code we had above to deal
with exceptions. This is getting out of hand - and it's where `TVar` comes in.

We'll model the accounts as `TVar` - transactional variable, and instead of
locks we'll use `Concurrent::atomically`.

```ruby
a = new TVar(100_000)
b = new TVar(100)

Concurrent::atomically do
  a.value -= 10
  b.value += 10
end
```

That short piece of code effectively solves all the concerns we identified
above. How it does it is described in the reference above. You just need to be
happy that any two `atomically` blocks (we call them transactions) that use an
overlapping set of `TVar` objects will appear to have happened as if there was a
big global lock on them, and that if any exception is raised in the block, it
will be as if the block never happened. But also keep in mind the important
points we detailed right at the start of the article about side effects and
repeated execution.
