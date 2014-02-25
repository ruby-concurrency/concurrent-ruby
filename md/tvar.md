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
