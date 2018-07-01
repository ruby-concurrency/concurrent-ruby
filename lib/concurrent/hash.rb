require 'concurrent/utility/engine'
require 'concurrent/thread_safe/util'

module Concurrent
  case
  when Concurrent.on_cruby?

    # @!macro [attach] concurrent_hash
    #
    #   A thread-safe subclass of Hash. This version locks against the object
    #   itself for every method call, ensuring only one thread can be reading
    #   or writing at a time. This includes iteration methods like `#each`,
    #   which takes the lock repeatedly when reading an item.
    #
    #   @see http://ruby-doc.org/core-2.2.0/Hash.html Ruby standard library `Hash`
    class Hash < ::Hash
    end

  when Concurrent.on_jruby?
    require 'jruby/synchronized'

    # @!macro concurrent_hash
    class Hash < ::Hash
      include JRuby::Synchronized
    end

  when Concurrent.on_rbx?
    require 'monitor'
    require 'concurrent/thread_safe/util/data_structures'

    # @!macro concurrent_hash
    class Hash < ::Hash
    end

    ThreadSafe::Util.make_synchronized_on_rbx Concurrent::Hash

  when Concurrent.on_truffleruby?
    require 'concurrent/thread_safe/util/data_structures'

    # @!macro concurrent_hash
    class Hash < ::Hash
    end

    ThreadSafe::Util.make_synchronized_on_truffleruby Concurrent::Hash

  else
    warn 'Possibly unsupported Ruby implementation'
    class Hash < ::Hash
    end

  end
end

