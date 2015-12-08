require 'concurrent_needed'
require 'concurrent/utility/engine'

FutureImplementation = case
                       when Concurrent.on_cruby?
                         require 'gvl_future'
                         GVLFuture
                       when Concurrent.on_rbx? || Concurrent.on_truffle?
                         require 'rbx_future'
                         RBXFuture
                       when Concurrent.on_jruby?
                         require 'jruby_future'
                         JRubyFuture
                       else
                         raise
                       end

require 'bench_fulfill'
