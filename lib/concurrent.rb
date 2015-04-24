require 'concurrent/version'

require 'concurrent/synchronization'
require 'concurrent/at_exit'

require 'concurrent/configuration'

require 'concurrent/actor'
require 'concurrent/atomics'
require 'concurrent/channels'
require 'concurrent/collections'
require 'concurrent/errors'
require 'concurrent/executors'
require 'concurrent/utilities'

require 'concurrent/atomic/atomic_reference'
require 'concurrent/agent'
require 'concurrent/async'
require 'concurrent/dataflow'
require 'concurrent/delay'
require 'concurrent/exchanger'
require 'concurrent/future'
require 'concurrent/ivar'
require 'concurrent/lazy_register'
require 'concurrent/mvar'
require 'concurrent/promise'
require 'concurrent/scheduled_task'
require 'concurrent/timer_task'
require 'concurrent/tvar'

# @!macro [new] monotonic_clock_warning
# 
#   @note Time calculations one all platforms and languages are sensitive to
#     changes to the system clock. To alleviate the potential problems
#     associated with changing the system clock while an application is running,
#     most modern operating systems provide a monotonic clock that operates
#     independently of the system clock. A monotonic clock cannot be used to
#     determine human-friendly clock times. A monotonic clock is used exclusively
#     for calculating time intervals. Not all Ruby platforms provide access to an
#     operating system monotonic clock. On these platforms a pure-Ruby monotonic
#     clock will be used as a fallback. An operating system monotonic clock is both
#     faster and more reliable than the pure-Ruby implementation. The pure-Ruby
#     implementation should be fast and reliable enough for most non-realtime
#     operations. At this time the common Ruby platforms that provide access to an
#     operating system monotonic clock are MRI 2.1 and above and JRuby (all versions).
#
#   @see http://linux.die.net/man/3/clock_gettime Linux clock_gettime(3)

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
