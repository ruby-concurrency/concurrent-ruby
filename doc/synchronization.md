> Quotations are used for notes.

> This document is work-in-progress.
> Intentions of this effort and document are: to summarize the behavior
> of Ruby in concurrent and parallel environment, initiate discussion,
> identify problems in the document, find flaws in the Ruby
> implementations if any, suggest what has to be enhanced in Ruby itself
> and cooperate towards the goal in all implementations (using
> `concurrent-ruby` as compatibility layer).
>
> It's not intention of this effort to introduce high-level concurrency
> abstractions like actors to the language, but rather to improve low-level
> concurrency support to add many more concurrency abstractions through gems.

# Synchronization

This layer provides tools to write concurrent abstractions independent of any
particular Ruby implementation. It is built on top of the Ruby memory model
which is also described here. `concurrent-ruby` abstractions are build using
this layer.

**Why?** Ruby is great expressive language, but it lacks in support for
well-defined low-level concurrent and parallel computation. It's hoped that this
document will provide ground steps for Ruby to become as good in this area as
in others.

Without a memory model and this layer it's very hard to write concurrent
abstractions for Ruby. To write a proper concurrent abstraction it often means
to reimplement it more than once for different Ruby runtimes, which is very
time-consuming and error-prone.

# Ruby memory model

The Ruby memory model is a framework allowing to reason about programs in
concurrent and parallel environment. It defines what variable writes can be
observed by a particular variable read, which is essential to be able to
determine if a program is correct. It is achieved by defining what subset of
all possible program execution orders is allowed.

A memory model sources:

-   [Java memory model](http://www.cs.umd.edu/~pugh/java/memoryModel/),
    and its [FAQ](http://www.cs.umd.edu/~pugh/java/memoryModel/jsr-133-faq.html)
-   [Java Memory Model Pragmatics](http://shipilev.net/blog/2014/jmm-pragmatics/)
-   [atomic&lt;&gt; Weapons 1](https://channel9.msdn.com/Shows/Going+Deep/Cpp-and-Beyond-2012-Herb-Sutter-atomic-Weapons-1-of-2)
and
[2](https://channel9.msdn.com/Shows/Going+Deep/Cpp-and-Beyond-2012-Herb-Sutter-atomic-Weapons-2-of-2)

Concurrent behavior sources of Ruby implementations:

-   Source codes.
-   [JRuby's wiki page](https://github.com/jruby/jruby/wiki/Concurrency-in-jruby)
-   [Rubinius's wiki page](http://rubini.us/doc/en/systems/concurrency/)

> A similar document for MRI was not found. Key fact about MRI is GVL (Global
> VM lock) which ensures that only one thread can interpret a Ruby code at any
> given time. When the GVL is handed from one thread to another a mutex is
> released by first and acquired by the second thread implying that everything
> done by first thread is visible to second thread. See
> [thread_pthread.c](https://github.com/ruby/ruby/blob/ruby_2_2/thread_pthread.c#L101-L107)
> and
> [thread_win32.c](https://github.com/ruby/ruby/blob/ruby_2_2/thread_win32.c#L95-L100).

This memory model was created by: comparing
[MRI](https://www.ruby-lang.org/en/), [JRuby](http://jruby.org/),
[JRuby+Truffle](https://github.com/jruby/jruby/wiki/Truffle),
[Rubinius](http://rubini.us/); taking account limitations of the implementations
or their platforms; inspiration drawn from other existing memory models (Java,
C++11). This is not a formal model.

Key properties are:

-   **volatility (V)** - A written value is immediately visible to any
    subsequent volatile read of the same variable on any Thread. (It has same
    meaning as in Java.)
-   **atomicity (A)** - Operation is either done or not as a whole.
-   **serialized (S)** - Operations are serialized in some order (they
    cannot disappear). This is a new property not mentioned in other memory
    models, since Java and C++ do not have dynamically defined fields. All
    operations on one line in a row of the tables bellow are serialized with
    each other.

### Core behavior:

| Operation | V | A | S | Notes |
|:----------|:-:|:-:|:-:|:-----|
| local variable read/write/definition | - | x | x | Local variables are determined during parsing, they are not usually dynamically added (with exception of `local_variable_set`). Therefore definition is quite rare. |
| instance variable read/write/(un)definition | - | x | x | Newly defined instance variables have to become visible eventually. |
| class variable read/write/(un)definition | x | x | x ||
| global variable read/write/definition | x | x | x | un-define us not possible currently. |
| constant variable read/write/(un)definition | x | x | x ||
| `Thread` local variable read/write/definition | - | x | x | un-define is not possible currently. |
| `Fiber` local variable read/write/definition | - | x | x | un-define is not possible currently. |
| method creation/redefinition/removal | x | x | x ||
| include/extend | x | x | x | If `AClass` is included `AModule`, `AClass` gets all `AModule`'s methods at once. |


Notes:

-   Variable read reads value from preexisting variable.
-   Variable definition creates new variable (operation is serialized with
    writes, implies an update cannot be lost).
-   A Module or a Class definition is actually a constant definition.
    The definition is atomic, it assigns the Module or the Class to the
    constant, then its methods are defined atomically one by one.
-   `||=`, `+=`, etc. are actually two operations read and write which implies
    that it's not an atomic operation. See volatile variables
    with compare-and-set.
-   Method invocation does not have any special properties that includes
    object initialization.

Current Implementation differences from the model:

-   MRI: everything is volatile.
-   JRuby: `Thread` and `Fiber` local variables are volatile. Instance
    variables are volatile on x86 and people may un/intentionally depend
    on the fact.
-   Class variables require investigation.

> TODO: updated with specific versions of the implementations.

### Threads

> TODO: add description of `Thread.new`, `#join`, etc.

### Source loading:

| Operation | V | A | S | Notes |
|:----------|:-:|:-:|:-:|:-----|
| requiring | x | x | x | File will not be required twice, classes and modules are still defined gradually. |
| autoload | x | x | x | Only one autoload at a time. |

Notes:

-   Beware of requiring and autoloading in concurrent programs, it's possible to
    see partially defined classes. Eager loading or blocking until class is
    fully loaded should be used to mitigate.

### Core classes

`Mutex`, `Monitor`, `Queue` have to work correctly on each implementation. Ruby
implementation VMs should not crash when for example `Array` or `Hash` is used
in parallel environment but it may loose updates, or raise Exceptions. (If
`Array` or `Hash` were synchronized it would have too much overhead when used
in a single thread.)

> `concurrent-ruby` contains synchronized versions of `Array` and `Hash` and
> other thread-safe data structure. 

> TODO: This section needs more work: e.g. Thread.raise and similar is an open
> issue, better not to be used.

### Standard libraries

Standard libraries were written for MRI so unless they are rewritten in
particular Ruby implementation they may contain hidden problems. Therefore it's
better to assume that they are not safe.

> TODO: This section needs more work.

# Extensions

The above described memory model is quite weak, e.g. A thread-safe immutable
object cannot be created. It requires final or volatile instance variables.

## Final instance variable

Objects inherited from `Synchronization::Object` provide a way how to ensure
that all instance variables that are set only once in constructor (therefore
effectively final) are safely published to all readers (assuming proper
construction - object instance does not escape during construction).

``` ruby
class ImmutableTreeNode < Concurrent::Synchronization::Object
  # mark this class to publish final instance variables safely
  safe_initialization!

  def initialize(left, right)
    # Call super to allow proper initialization.
    super()
    # By convention final instance variables have CamelCase names
    # to distinguish them from ordinary instance variables.
    @Left  = left
    @Right = right
  end

  # Define thread-safe readers.
  def left
    # No need to synchronize or otherwise protect, it's already
    # guaranteed to be visible.
    @Left
  end    

  def right
    @Right
  end
end
```

Once `safe_initialization!` is called on a class it transitively applies to all
its children.

> It's implemented by adding `new`, when `safe_initialization!` is called, as
> follows:
>
> ``` ruby
> def self.new(*)
>   object = super
> ensure
>   object.ensure_ivar_visibility! if object
> end
> ```
>
> therefore `new` should not be overridden.

## Volatile instance variable

`Synchronization::Object` children can have volatile instance variables. A Ruby
library cannot alter meaning of `@a_name` expression therefore when a
`attr_volatile :a_name` is called, declaring the instance variable named
`a_name` to be volatile, it creates method accessors.

> However there is Ruby [issue](https://redmine.ruby-lang.org/issues/11539)
> filed to address this.

``` ruby
# Simple counter with cheap reads.
class Counter < Concurrent::Synchronization::Object
  # Declare instance variable value to be volatile and its
  # reader and writer to be private. `attr_volatile` returns
  # names of created methods.
  private *attr_volatile(:value)
  safe_initialization!

  def initialize(value)
    # Call super to allow proper initialization.
    super()
    # Create a reentrant lock instance held in final ivar
    # to be able to protect writer.
    @Lock = Concurrent::Synchronization::Lock.new
    # volatile write
    self.value = value
  end

  # Very cheap reader of the Counter's current value, just a volatile read.
  def count
    # volatile read
    value
  end

  # Safely increments the value without loosing updates
  # (as it would happen with just += used).
  def increment(add)
    # Wrap the two volatile operations to make them atomic.
    @Lock.synchronize do
      # volatile write and read
      self.value = self.value + add
    end
  end   
end
```

> This is currently planned to be migrated to a module to be able to add
> volatile fields any object not just `Synchronization::Object` children. The
> instance variable itself is named `"@volatile_#{name}"` to distinguish it and
> to prevent direct access by name.

## Volatile instance variable with compare-and-set

Some concurrent abstractions may need to do compare-and-set on the volatile
instance variables to avoid synchronization, then `attr_volatile_with_cas` is
used.

``` ruby
# Simplified clojure's Atom implementation
class Atom < Concurrent::Synchronization::Object
  safe_initialization!
  # Make all methods private
  private *attr_volatile_with_cas(:value)
  # with exception of reader
  public :value

  def initialize(value, validator = -> (v) { true })
    # Call super to allow proper initialization.
    super()
    # volatile write
    self.value = value
    @Validator = validator
  end

  # Allows to swap values computed from an old_value with function
  # without using blocking synchronization.
  def swap(*args, &function)
    loop do
      old_value = self.value # volatile read
      begin
        # compute new value
        new_value = function.call(old_value, *args)
        # return old_value if validation fails
        break old_value unless valid?(new_value)
        # return new_value only if compare-and-set is successful
        # on value instance variable, otherwise repeat
        break new_value if compare_and_set_value(old_value, new_value)
      rescue
        break old_value
      end
    end
  end    

  private      

  def valid?(new_value)
    @Validator.call(new_value) rescue false
  end
end
```

`attr_volatile_with_cas` defines five methods for a given instance variable
name. For name `value` they are:

``` ruby
self.value                                      #=> the_value
self.value=(new_value)                          #=> new_value
self.swap_value(new_value)                      #=> old_value
self.compare_and_set_value(expected, new_value) #=> true || false
self.update_value(&function)                    #=> function.call(old_value)
```

Three of them were used in the example above.

> Current implementation relies on final instance variables where a instance of
> `AtomicReference` is held to provide compare-and-set operations. That creates
> extra indirection which is hoped to be removed over time when better
> implementation will become available in Ruby implementations. The
> instance variable itself is named `"@VolatileCas#{camelized name}"` to
> distinguish it and to prevent direct access by name.
