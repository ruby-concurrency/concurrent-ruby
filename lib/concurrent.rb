require 'concurrent/version'
require 'concurrent/configuration'

require 'concurrent/atomic'
require 'concurrent/count_down_latch'
require 'concurrent/condition'
require 'concurrent/copy_on_notify_observer_set'
require 'concurrent/copy_on_write_observer_set'
require 'concurrent/safe_task_executor'
require 'concurrent/ivar'

require 'concurrent/actor'
require 'concurrent/agent'
require 'concurrent/async'
require 'concurrent/dataflow'
require 'concurrent/delay'
require 'concurrent/dereferenceable'
require 'concurrent/event'
require 'concurrent/exchanger'
require 'concurrent/future'
require 'concurrent/mvar'
require 'concurrent/obligation'
require 'concurrent/observable'
require 'concurrent/postable'
require 'concurrent/processor_count'
require 'concurrent/promise'
require 'concurrent/runnable'
require 'concurrent/scheduled_task'
require 'concurrent/stoppable'
require 'concurrent/supervisor'
require 'concurrent/thread_local_var'
require 'concurrent/timer_task'
require 'concurrent/tvar'
require 'concurrent/utilities'

require 'concurrent/channel/channel'
require 'concurrent/channel/unbuffered_channel'
require 'concurrent/channel/buffered_channel'
require 'concurrent/channel/ring_buffer'
require 'concurrent/channel/blocking_ring_buffer'

require 'concurrent/actor_context'
require 'concurrent/simple_actor_ref'

require 'concurrent/cached_thread_pool'
require 'concurrent/fixed_thread_pool'
require 'concurrent/immediate_executor'
require 'concurrent/per_thread_executor'
require 'concurrent/single_thread_executor'
require 'concurrent/thread_pool_executor'

# Modern concurrency tools for Ruby. Inspired by Erlang, Clojure, Scala, Haskell,
# F#, C#, Java, and classic concurrency patterns.
# 
# The design goals of this gem are:
# 
# * Stay true to the spirit of the languages providing inspiration
# * But implement in a way that makes sense for Ruby
# * Keep the semantics as idiomatic Ruby as possible
# * Support features that make sense in Ruby
# * Exclude features that don't make sense in Ruby
# * Be small, lean, and loosely coupled
module Concurrent

end
