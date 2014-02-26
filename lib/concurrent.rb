require 'concurrent/version'

require 'concurrent/atomic_counter'
require 'concurrent/count_down_latch'
require 'concurrent/condition'
require 'concurrent/copy_on_notify_observer_set'
require 'concurrent/copy_on_write_observer_set'
require 'concurrent/safe_task_executor'

require 'concurrent/actor'
require 'concurrent/agent'
require 'concurrent/contract'
require 'concurrent/channel'
require 'concurrent/dataflow'
require 'concurrent/dereferenceable'
require 'concurrent/event'
require 'concurrent/future'
require 'concurrent/mvar'
require 'concurrent/obligation'
require 'concurrent/postable'
require 'concurrent/promise'
require 'concurrent/runnable'
require 'concurrent/scheduled_task'
require 'concurrent/stoppable'
require 'concurrent/supervisor'
require 'concurrent/threadlocalvar'
require 'concurrent/timer_task'
require 'concurrent/utilities'

require 'concurrent/global_thread_pool'

require 'concurrent/cached_thread_pool'
require 'concurrent/fixed_thread_pool'
require 'concurrent/immediate_executor'

require 'concurrent/event_machine_defer_proxy' if defined?(EventMachine)

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
