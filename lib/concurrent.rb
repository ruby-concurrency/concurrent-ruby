require 'concurrent/version'

require 'concurrent/atomic'
require 'concurrent/count_down_latch'
require 'concurrent/condition'
require 'concurrent/copy_on_notify_observer_set'
require 'concurrent/copy_on_write_observer_set'
require 'concurrent/safe_task_executor'
require 'concurrent/ivar'

require 'concurrent/actor'
require 'concurrent/actor_method_dispatcher'
require 'concurrent/actor_server'
require 'concurrent/agent'
require 'concurrent/channel'
require 'concurrent/dataflow'
require 'concurrent/delay'
require 'concurrent/dereferenceable'
require 'concurrent/event'
require 'concurrent/future'
require 'concurrent/mvar'
require 'concurrent/obligation'
require 'concurrent/postable'
require 'concurrent/promise'
require 'concurrent/remote_actor'
require 'concurrent/runnable'
require 'concurrent/scheduled_task'
require 'concurrent/stoppable'
require 'concurrent/supervisor'
require 'concurrent/thread_local_var'
require 'concurrent/timer_task'
require 'concurrent/utilities'

require 'concurrent/global_thread_pool'
require 'concurrent/cached_thread_pool'
require 'concurrent/fixed_thread_pool'
require 'concurrent/immediate_executor'

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
