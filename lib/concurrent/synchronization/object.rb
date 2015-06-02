module Concurrent
  module Synchronization

    # @api private
    Implementation = case
                     when Concurrent.on_jruby?
                       JavaObject
                     when Concurrent.on_cruby? && Concurrent.ruby_version(:<=, 1, 9, 3)
                       MonitorObject
                     when Concurrent.on_cruby? && Concurrent.ruby_version(:>, 1, 9, 3)
                       MutexObject
                     when Concurrent.on_rbx?
                       RbxObject
                     else
                       warn 'Possibly unsupported Ruby implementation'
                       MutexObject
                     end
    private_constant :Implementation

    # @see AbstractObject AbstractObject which defines interface of this class.
    class Object < Implementation
    end
  end
end
