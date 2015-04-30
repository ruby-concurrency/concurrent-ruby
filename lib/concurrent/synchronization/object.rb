module Concurrent
  module Synchronization
    Implementation = case
                     when Concurrent.on_jruby?
                       JavaObject
                     when Concurrent.on_cruby? && (RUBY_VERSION.split('.').map(&:to_i) <=> [1, 9, 3]) <= 0
                       MonitorObject
                     when Concurrent.on_cruby?
                       MutexObject
                     when Concurrent.on_rbx?
                       RbxObject
                     else
                       MutexObject
                     end
    private_constant :Implementation

    # @see AbstractObject AbstractObject which defines interface of this class.
    class Object < Implementation
    end
  end
end
