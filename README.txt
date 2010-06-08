atomic: An atomic reference implementation for JRuby and green or GIL-threaded
Ruby implementations (MRI 1.8/1.9, Rubinius)

== Summary ==

This library provides:

* an Atomic class that guarantees atomic updates to its contained value

The Atomic class provides accessors for the contained "value" plus two update
methods:

* update will run the provided block, passing the current value and replacing
  it with the block result iff the value has not been changed in the mean time.
  It may run the block repeatedly if there are other concurrent updates in
  progress.
* try_update will run the provided block, passing the current value and
  replacing it with the block result. If the value changes before the update
  can happen, it will throw Atomic::ConcurrentUpdateError.

The atomic repository is at http://github.com/headius/ruby-atomic.

== Usage ==

require 'atomic'

my_atomic = Atomic.new(0)
my_atomic.update {|v| v + 1}
begin
  my_atomic.try_update {|v| v + 1}
rescue Atomic::ConcurrentUpdateError => cue
  # deal with it (retry, propagate, etc)
end