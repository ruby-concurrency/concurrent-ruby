require 'concurrent/utility/engine'
require 'concurrent/constants'

module Concurrent
  # @!visibility private
  # @!macro internal_implementation_note
  #
  # An abstract implementation of local storage, with sub-classes for
  # per-thread and per-fiber locals.
  #
  # Each execution context (EC, thread or fiber) has a lazily initialized array
  # of local variable values. Each time a new local variable is created, we
  # allocate an "index" for it.
  #
  # For example, if the allocated index is 1, that means slot #1 in EVERY EC's
  # locals array will be used for the value of that variable.
  #
  # The good thing about using a per-EC structure to hold values, rather than
  # a global, is that no synchronization is needed when reading and writing
  # those values (since the structure is only ever accessed by a single
  # thread).
  #
  # Of course, when a local variable is GC'd, 1) we need to recover its index
  # for use by other new local variables (otherwise the locals arrays could
  # get bigger and bigger with time), and 2) we need to null out all the
  # references held in the now-unused slots (both to avoid blocking GC of those
  # objects, and also to prevent "stale" values from being passed on to a new
  # local when the index is reused).
  #
  # Because we need to null out freed slots, we need to keep references to
  # ALL the locals arrays, so we can null out the appropriate slots in all of
  # them. This is why we need to use a finalizer to clean up the locals array
  # when the EC goes out of scope.
  class AbstractLocals
    def initialize(name_prefix = :concurrent_locals)
      @free = []
      @lock = Mutex.new
      @all_locals = {}
      @next = 0

      @name = :"#{name_prefix}_#{object_id}"
    end

    def synchronize
      @lock.synchronize { yield }
    end

    if Concurrent.on_cruby?
      def weak_synchronize
        yield
      end
    else
      alias_method :weak_synchronize, :synchronize
    end

    def next_index(target)
      index = synchronize do
        if @free.empty?
          @next += 1
        else
          @free.pop
        end
      end

      # When the target goes out of scope, we should free the associated index
      # and all values stored into it.
      ObjectSpace.define_finalizer(target, target_finalizer(index))

      return index
    end

    def free_index(index)
      weak_synchronize do
        # The cost of GC'ing a TLV is linear in the number of ECs using local
        # variables. But that is natural! More ECs means more storage is used
        # per local variable. So naturally more CPU time is required to free
        # more storage.
        #
        # DO NOT use each_value which might conflict with new pair assignment
        # into the hash in #set method.
        @all_locals.values.each do |locals|
          locals[index] = nil
        end

        # free index has to be published after the arrays are cleared:
        @free << index
      end
    end

    def fetch(index, default = nil)
      if locals = self.locals
        value = locals[index]
      end

      if value.nil?
        if block_given?
          yield
        else
          default
        end
      elsif value.equal?(NULL)
        nil
      else
        value
      end
    end

    def set(index, value)
      locals = self.locals!
      locals[index] = (value.nil? ? NULL : value)

      value
    end

    private

    # When the target index goes out of scope, clean up that slot across all locals currently assigned.
    def target_finalizer(index)
      proc do
        free_index(index)
      end
    end

    # When a target (locals) goes out of scope, delete the locals from all known locals.
    def locals_finalizer(locals_object_id)
      proc do |locals_id|
        weak_synchronize do
          @all_locals.delete(locals_object_id)
        end
      end
    end

    # Returns the locals for the current scope, or nil if none exist.
    def locals
      raise NotImplementedError
    end

    # Returns the locals for the current scope, creating them if necessary.
    def locals!
      raise NotImplementedError
    end
  end

  # @!visibility private
  # @!macro internal_implementation_note
  # An array-backed storage of indexed variables per thread.
  class ThreadLocals < AbstractLocals
    def locals
      Thread.current.thread_variable_get(@name)
    end

    def locals!
      thread = Thread.current
      locals = thread.thread_variable_get(@name)

      unless locals
        locals = thread.thread_variable_set(@name, [])
        weak_synchronize do
          @all_locals[locals.object_id] = locals
          # When the thread goes out of scope, we should delete the associated locals:
          ObjectSpace.define_finalizer(thread, locals_finalizer(locals.object_id))
        end
      end

      return locals
    end
  end

  # @!visibility private
  # @!macro internal_implementation_note
  # An array-backed storage of indexed variables per fiber.
  class FiberLocals < AbstractLocals
    def locals
      Thread.current[@name]
    end

    def locals!
      thread = Thread.current
      locals = thread[@name]

      unless locals
        locals = thread[@name] = []
        weak_synchronize do
          @all_locals[locals.object_id] = locals
          # When the thread goes out of scope, we should delete the associated locals:
          ObjectSpace.define_finalizer(Fiber.current, locals_finalizer(locals.object_id))
        end
      end

      return locals
    end
  end
end
