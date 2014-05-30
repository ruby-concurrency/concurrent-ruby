atomic: An atomic reference implementation for JRuby, Rubinius, and MRI.
========================================================================

[![Build Status](https://travis-ci.org/headius/ruby-atomic.png?branch=master)](https://travis-ci.org/headius/ruby-atomic)

Summary
=======

This library provides:

* an Atomic class that guarantees atomic updates to its contained value

The Atomic class provides accessors for the contained "value" plus two update methods:

* update will run the provided block, passing the current value and replacing it with the block result if the value has not been changed in the meantime. It may run the block repeatedly if there are other concurrent updates in progress.
* try_update will run the provided block, passing the current value and replacing it with the block result. If the value changes before the update can happen, it will throw an Atomic::ConcurrentUpdateError.

The atomic repository is at http://github.com/headius/ruby-atomic.

Usage
=====

The simplest way to use "atomic" is to call the "update" or "try_update" methods.

"try_update" and "update" both call the given block, passing the current value and using the block's result as the new value. If the value is updated by another thread before the block completes, "try update" raises a ConcurrentUpdateError and "update" retries the block. Because "update" may call the block several times when multiple threads are all updating the same value, the block's logic should be kept as simple as possible.

```ruby
require 'atomic'

my_atomic = Atomic.new(0)
my_atomic.update {|v| v + 1}
begin
  my_atomic.try_update {|v| v + 1}
rescue Atomic::ConcurrentUpdateError => cue
  # deal with it (retry, propagate, etc)
end
```

It's also possible to use the regular get/set operations on the Atomic, if you want to avoid the exception and respond to contended changes in some other way.

```ruby
my_atomic = Atomic.new(0)
my_atomic.value # => 0
my_atomic.value = 1
my_atomic.swap(2) # => 1
my_atomic.compare_and_swap(2, 3) # => true, updated to 3
my_atomic.compare_and_swap(2, 3) # => false, current is not 2
```

Building
========

As of 1.1.0, JDK8 is required to build the atomic gem, since it attempts to use the new atomic Unsafe.getAndSetObject method only in JDK8. The resulting code should still work fine as far back as Java 5.
