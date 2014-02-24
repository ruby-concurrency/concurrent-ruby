# MVar

An `MVar` is a synchronized single element container. They are empty or contain
one item. Taking a value from an empty `MVar` blocks, as does putting a value
into a full one. You can either think of them as blocking queue of length one,
or a special kind of mutable variable.

On top of the fundamental `#put` and `#take` operations, we also provide a
`#mutate` that is atomic with respect to operations on the same instance. These
operations all support timeouts.

We also support non-blocking operations `#try_put!` and `#try_take!`, a `#set!`
that ignores existing values, and a `#modify!` that yields `MVar::EMPTY` if the
`MVar` is empty and can be used to set `MVar::EMPTY`. You shouldn't use these
operations in the first instance.

`MVar is related to M-structures in Id, MVar in Haskell and SyncVar in Scala.
`See

1.  P. Barth, R. Nikhil, and Arvind. M-Structures: Extending a parallel, non-
strict, functional language with state. In Proceedings of the 5th ACM Conference
on Functional Programming Languages and Computer Architecture (FPCA), 1991.

2.  S. Peyton Jones, A. Gordon, and S. Finne. Concurrent Haskell. In Proceedings of the 23rd Symposium on Principles of Programming Languages (PoPL), 1996.

Note that unlike the original Haskell paper, our `#take` is blocking. This is
how Haskell and Scala do it today.
