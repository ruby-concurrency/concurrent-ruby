require 'concurrent/utility/native_extension_loader' # load native parts first

require 'concurrent/synchronization/object'
require 'concurrent/synchronization/lockable_object'
require 'concurrent/synchronization/condition'
require 'concurrent/synchronization/lock'

module Concurrent
  # {include:file:docs-source/synchronization.md}
  # {include:file:docs-source/synchronization-notes.md}
  module Synchronization
  end
end

