require 'concurrent/utility/engine'
require 'concurrent/synchronized_object_implementations/abstract'
require 'concurrent/native_extensions'
require 'concurrent/synchronized_object_implementations/mutex'
require 'concurrent/synchronized_object_implementations/monitor'
require 'concurrent/synchronized_object_implementations/rbx'

module Concurrent
  module SynchronizedObjectImplementations
    class Implementation < case
                           when Concurrent.on_jruby?
                             Java

                           when Concurrent.on_cruby? && (RUBY_VERSION.split('.').map(&:to_i) <=> [1, 9, 3]) >= 0
                             Monitor

                           when Concurrent.on_cruby?
                             Mutex

                           when Concurrent.on_rbx?
                             Rbx

                           else
                             Mutex
                           end
    end
  end

  SynchronizedObject = SynchronizedObjectImplementations::Implementation

end
