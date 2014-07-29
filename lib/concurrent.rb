require 'concurrent/version'

require 'concurrent/configuration'

require 'concurrent/atomics'
require 'concurrent/channels'
require 'concurrent/collections'
require 'concurrent/executors'
require 'concurrent/utilities'

require 'concurrent/actor'
require 'concurrent/atomic'
require 'concurrent/lazy_register'
require 'concurrent/agent'
require 'concurrent/async'
require 'concurrent/dataflow'
require 'concurrent/delay'
require 'concurrent/dereferenceable'
require 'concurrent/errors'
require 'concurrent/exchanger'
require 'concurrent/future'
require 'concurrent/ivar'
require 'concurrent/mvar'
require 'concurrent/obligation'
require 'concurrent/observable'
require 'concurrent/options_parser'
require 'concurrent/promise'
require 'concurrent/scheduled_task'
require 'concurrent/timer_task'
require 'concurrent/tvar'

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
