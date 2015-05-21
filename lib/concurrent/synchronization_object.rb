require 'concurrent/utility/engine'
require 'concurrent/native_extensions' # JavaObject
require 'concurrent/synchronization_object_impl/abstract_object'
require 'concurrent/synchronization_object_impl/mutex_object'
require 'concurrent/synchronization_object_impl/monitor_object'
require 'concurrent/synchronization_object_impl/rbx_object'

module Concurrent

  # {include:file:doc/synchronization.md}
  module SynchronizationObjectImpl
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
  end

  # @see AbstractObject AbstractObject which defines interface of this class.
  class SynchronizationObject < SynchronizationObjectImpl::Implementation
  end
end
