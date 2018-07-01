require 'concurrent/utility/engine'
require 'concurrent/thread_safe/util'
require 'set'

module Concurrent
  case
  when Concurrent.on_cruby?

    # Because MRI never runs code in parallel, the existing
    # non-thread-safe structures should usually work fine.

    # @!macro [attach] concurrent_Set
    #
    #   A thread-safe subclass of Set. This version locks against the object
    #   itself for every method call, ensuring only one thread can be reading
    #   or writing at a time. This includes iteration methods like `#each`.
    #
    #   @note `a += b` is **not** a **thread-safe** operation on
    #   `Concurrent::Set`. It reads Set `a`, then it creates new `Concurrent::Set`
    #   which is union of `a` and `b`, then it writes the union to `a`.
    #   The read and write are independent operations they do not form a single atomic
    #   operation therefore when two `+=` operations are executed concurrently updates
    #   may be lost. Use `#merge` instead.
    #
    #   @see http://ruby-doc.org/stdlib-2.4.0/libdoc/set/rdoc/Set.html Ruby standard library `Set`
    class Set < ::Set;
    end

  when Concurrent.on_jruby?
    require 'jruby/synchronized'

    # @!macro concurrent_Set
    class Set < ::Set
      include JRuby::Synchronized
    end

  when Concurrent.on_rbx?
    require 'monitor'
    require 'concurrent/thread_safe/util/data_structures'

    # @!macro concurrent_Set
    class Set < ::Set
    end

    ThreadSafe::Util.make_synchronized_on_rbx Concurrent::Set

  when Concurrent.on_truffleruby?
    require 'concurrent/thread_safe/util/data_structures'

    # @!macro concurrent_array
    class Set < ::Set
    end

    ThreadSafe::Util.make_synchronized_on_truffleruby Concurrent::Set

  else
    warn 'Possibly unsupported Ruby implementation'
    class Set < ::Set
    end
  end
end

