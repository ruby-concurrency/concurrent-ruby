# TODO: Figure out if these can be autoloaded.
require 'concurrent/synchronization/abstract_struct'
require 'concurrent/synchronization/abstract_object'
require 'concurrent/utility/native_extension_loader' # load native parts first
Concurrent.load_native_extensions

module Concurrent
  # {include:file:docs-source/synchronization.md}
  # {include:file:docs-source/synchronization-notes.md}
  module Synchronization
    autoload :MriObject, 'concurrent/synchronization/mri_object'
    autoload :JRubyObject, 'concurrent/synchronization/jruby_object'
    autoload :RbxObject, 'concurrent/synchronization/rbx_object'
    autoload :TruffleRubyObject, 'concurrent/synchronization/truffleruby_object'
    autoload :Object, 'concurrent/synchronization/object'
    autoload :Volatile, 'concurrent/synchronization/volatile'

    autoload :AbstractLockableObject, 'concurrent/synchronization/abstract_lockable_object'
    autoload :MutexLockableObject, 'concurrent/synchronization/mutex_lockable_object'
    autoload :JRubyLockableObject, 'concurrent/synchronization/jruby_lockable_object'
    autoload :RbxLockableObject, 'concurrent/synchronization/rbx_lockable_object'

    autoload :LockableObject, 'concurrent/synchronization/lockable_object'

    autoload :Condition, 'concurrent/synchronization/condition'
    autoload :Lock, 'concurrent/synchronization/lock'
  end
end

