### Next Release v0.8.0 (25 January 2015)

* C extension for MRI have been extracted into the `concurrent-ruby-ext` companion gem.
  Please see the README for more detail.
* Better variable isolation in `Promise` and `Future` via an `:args` option
* Continued to update intermittently failing tests

## Current Release v0.7.2 (24 January 2015)

* New `Semaphore` class based on [java.util.concurrent.Semaphore](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/Semaphore.html)
* New `Promise.all?` and `Promise.any?` class methods
* Renamed `:overflow_policy` on thread pools to `:fallback_policy`
* Thread pools still accept the `:overflow_policy` option but display a warning
* Thread pools now implement `fallback_policy` behavior when not running (rather than universally rejecting tasks)
* Fixed minor `set_deref_options` constructor bug in `Promise` class
* Fixed minor `require` bug in `ThreadLocalVar` class
* Fixed race condition bug in `TimerSet` class
* Fixed race condition bug in `TimerSet` class
* Fixed signal bug in `TimerSet#post` method
* Numerous non-functional updates to clear warning when running in debug mode
* Fixed more intermittently failing tests
* Tests now run on new Travis build environment
* Multiple documentation updates

### Release v0.7.1 (4 December 2014)

Please see the [roadmap](https://github.com/ruby-concurrency/concurrent-ruby/issues/142) for more information on the next planned release.

* Added `flat_map` method to `Promise`
* Added `zip` method to `Promise`
* Fixed bug with logging in `Actor`
* Improvements to `Promise` tests
* Removed actor-experimental warning
* Added an `IndirectImmediateExecutor` class
* Allow disabling auto termination of global executors
* Fix thread leaking in `ThreadLocalVar` (uses `Ref` gem on non-JRuby systems)
* Fix thread leaking when pruning pure-Ruby thread pools
* Prevent `Actor` from using an `ImmediateExecutor` (causes deadlock)
* Added missing synchronizations to `TimerSet`
* Fixed bug with return value of `Concurrent::Actor::Utils::Pool#ask`
* Fixed timing bug in `TimerTask`
* Fixed bug when creating a `JavaThreadPoolExecutor` with minimum pool size of zero
* Removed confusing warning when not using native extenstions
* Improved documentation

### Release v0.7.0 (13 August 2014)

* Merge the [atomic](https://github.com/ruby-concurrency/atomic) gem
  - Pure Ruby `MutexAtomic` atomic reference class
  - Platform native atomic reference classes `CAtomic`, `JavaAtomic`, and `RbxAtomic`
  - Automated [build process](https://github.com/ruby-concurrency/rake-compiler-dev-box)
  - Fat binary releases for [multiple platforms](https://rubygems.org/gems/concurrent-ruby/versions) including Windows (32/64), Linux (32/64), OS X (64-bit), Solaris (64-bit), and JRuby
* C native `CAtomicBoolean`
* C native `CAtomicFixnum`
* Refactored intermittently failing tests
* Added `dataflow!` and `dataflow_with!` methods to match `Future#value!` method
* Better handling of timeout in `Agent`
* Actor Improvements
  - Fine-grained implementation using chain of behaviors. Each behavior is responsible for single aspect like: `Termination`, `Pausing`, `Linking`, `Supervising`, etc. Users can create custom Actors easily based on their needs.
  - Supervision was added. `RestartingContext` will pause on error waiting on its supervisor to decide what to do next ( options are `:terminate!`, `:resume!`, `:reset!`, `:restart!`). Supervising behavior also supports strategies `:one_for_one` and `:one_for_all`.
  - Linking was added to be able to monitor actor's events like: `:terminated`, `:paused`, `:restarted`, etc.
  - Dead letter routing added. Rejected envelopes are collected in a configurable actor (default: `Concurrent::Actor.root.ask!(:dead_letter_routing)`)
  - Old `Actor` class removed and replaced by new implementation previously called `Actress`. `Actress` was kept as an alias for `Actor` to keep compatibility.
  - `Utils::Broadcast` actor which allows Publish–subscribe pattern.
* More executors for managing serialized operations
  - `SerializedExecution` mixin module
  - `SerializedExecutionDelegator` for serializing *any* executor
* Updated `Async` with serialized execution
* Updated `ImmediateExecutor` and `PerThreadExecutor` with full executor service lifecycle
* Added a `Delay` to root `Actress` initialization 
* Minor bug fixes to thread pools
* Refactored many intermittently failing specs
* Removed Java interop warning `executor.rb:148 warning: ambiguous Java methods found, using submit(java.lang.Runnable)`
* Fixed minor bug in `RubyCachedThreadPool` overflow policy
* Updated tests to use [RSpec 3.0](http://myronmars.to/n/dev-blog/2014/05/notable-changes-in-rspec-3)
* Removed deprecated `Actor` class
* Better support for Rubinius

### Release v0.6.1 (14 June 2014)

* Many improvements to `Concurrent::Actress`
* Bug fixes to `Concurrent::RubyThreadPoolExecutor`
* Fixed several brittle tests
* Moved documentation to http://ruby-concurrency.github.io/concurrent-ruby/frames.html

### Release v0.6.0 (25 May 2014)

* Added `Concurrent::Observable` to encapsulate our thread safe observer sets
* Improvements to new `Channel`
* Major improvements to `CachedThreadPool` and `FixedThreadPool`
* Added `SingleThreadExecutor`
* Added `Current::timer` function
* Added `TimerSet` executor
* Added `AtomicBoolean`
* `ScheduledTask` refactoring
* Pure Ruby and JRuby-optimized `PriorityQueue` classes
* Updated `Agent` behavior to more closely match Clojure
* Observer sets support block callbacks to the `add_observer` method
* New algorithm for thread creation in `RubyThreadPoolExecutor`
* Minor API updates to `Event`
* Rewritten `TimerTask` now an `Executor` instead of a `Runnable`
* Fixed many brittle specs
* Renamed `FixedThreadPool` and `CachedThreadPool` to `RubyFixedThreadPool` and `RubyCachedThreadPool`
* Created JRuby optimized `JavaFixedThreadPool` and `JavaCachedThreadPool`
* Consolidated fixed thread pool tests into `spec/concurrent/fixed_thread_pool_shared.rb` and  `spec/concurrent/cached_thread_pool_shared.rb`
* `FixedThreadPool` now subclasses `RubyFixedThreadPool` or `JavaFixedThreadPool` as appropriate
* `CachedThreadPool` now subclasses `RubyCachedThreadPool` or `JavaCachedThreadPool` as appropriate
* New `Delay` class
* `Concurrent::processor_count` helper function
* New `Async` module
* Renamed `NullThreadPool` to `PerThreadExecutor`
* Deprecated `Channel` (we are planning a new implementation based on [Go](http://golangtutorials.blogspot.com/2011/06/channels-in-go.html))
* Added gem-level [configuration](http://robots.thoughtbot.com/mygem-configure-block)
* Deprecated `$GLOBAL_THREAD_POOL` in lieu of gem-level configuration
* Removed support for Ruby [1.9.2](https://www.ruby-lang.org/en/news/2013/12/17/maintenance-of-1-8-7-and-1-9-2/)
* New `RubyThreadPoolExecutor` and `JavaThreadPoolExecutor` classes
* All thread pools now extend the appropriate thread pool executor classes
* All thread pools now support `:overflow_policy` (based on Java's [reject policies](http://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html))
* Deprecated `UsesGlobalThreadPool` in lieu of explicit `:executor` option (dependency injection) on `Future`, `Promise`, and `Agent`
* Added `Concurrent::dataflow_with(executor, *inputs)` method to support executor dependency injection for dataflow
* Software transactional memory with `TVar` and `Concurrent::atomically`
* First implementation of [new, high-performance](https://github.com/ruby-concurrency/concurrent-ruby/pull/49) `Channel`
* `Actor` is deprecated in favor of new experimental actor implementation [#73](https://github.com/ruby-concurrency/concurrent-ruby/pull/73). To avoid namespace collision it is living in `Actress` namespace until `Actor` is removed in next release.

### Release v0.5.0

This is the most significant release of this gem since its inception. This release includes many improvements and optimizations. It also includes several bug fixes. The major areas of focus for this release were:

* Stability improvements on Ruby versions with thread-level parallelism ([JRuby](http://jruby.org/) and [Rubinius](http://rubini.us/))
* Creation of new low-level concurrency abstractions
* Internal refactoring to use the new low-level abstractions

Most of these updates had no effect on the gem API. There are a few notable exceptions which were unavoidable. Please read the [release notes](API-Updates-in-v0.5.0) for more information.

Specific changes include:

* New class `IVar`
* New class `MVar`
* New class `ThreadLocalVar`
* New class `AtomicFixnum`
* New class method `dataflow`
* New class `Condition`
* New class `CountDownLatch`
* New class `DependencyCounter`
* New class `SafeTaskExecutor`
* New class `CopyOnNotifyObserverSet`
* New class `CopyOnWriteObserverSet`
* `Future` updated with `execute` API
* `ScheduledTask` updated with `execute` API
* New `Promise` API
* `Future` now extends `IVar`
* `Postable#post?` now returns an `IVar`
* Thread safety fixes to `Dereferenceable`
* Thread safety fixes to `Obligation`
* Thread safety fixes to `Supervisor`
* Thread safety fixes to `Event`
* Various other thread safety (race condition) fixes
* Refactored brittle tests
* Implemented pending tests
* Added JRuby and Rubinius as Travis CI build targets
* Added [CodeClimate](https://codeclimate.com/) code review
* Improved YARD documentation
