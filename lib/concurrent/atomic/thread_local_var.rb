require 'thread'

module Concurrent

  # @!macro [attach] thread_local_var
  #
  #   A `ThreadLocalVar` is a variable where the value is different for each thread.
  #   Each variable may have a default value, but when you modify the variable only
  #   the current thread will ever see that change.
  #   
  #   @example
  #     v = ThreadLocalVar.new(14)
  #     v.value #=> 14
  #     v.value = 2
  #     v.value #=> 2
  #   
  #   @example
  #     v = ThreadLocalVar.new(14)
  #   
  #     t1 = Thread.new do
  #       v.value #=> 14
  #       v.value = 1
  #       v.value #=> 1
  #     end
  #   
  #     t2 = Thread.new do
  #       v.value #=> 14
  #       v.value = 2
  #       v.value #=> 2
  #     end
  #   
  #     v.value #=> 14
  #
  #   @see https://docs.oracle.com/javase/7/docs/api/java/lang/ThreadLocal.html Java ThreadLocal
  #
  # @!visibility private
  class AbstractThreadLocalVar

    # @!visibility private
    NIL_SENTINEL = Object.new
    private_constant :NIL_SENTINEL

    # @!macro [attach] thread_local_var_method_initialize
    #
    #   Creates a thread local variable.
    #
    #   @param [Object] default the default value when otherwise unset
    def initialize(default = nil)
      @default = default
      allocate_storage
    end

    # @!macro [attach] thread_local_var_method_get
    #
    #   Returns the value in the current thread's copy of this thread-local variable.
    #
    #   @return [Object] the current value
    def value
      raise NotImplementedError
    end

    # @!macro [attach] thread_local_var_method_set
    #
    #   Sets the current thread's copy of this thread-local variable to the specified value.
    #
    #   @param [Object] value the value to set
    #   @return [Object] the new value
    def value=(value)
      raise NotImplementedError
    end

    # @!macro [attach] thread_local_var_method_bind
    #
    #   Bind the given value to thread local storage during
    #   execution of the given block.
    #
    #   @param [Object] value the value to bind
    #   @yield the operation to be performed with the bound variable
    #   @return [Object] the value
    def bind(value, &block)
      raise NotImplementedError
    end

    protected

    # @!visibility private
    def allocate_storage
      raise NotImplementedError
    end
  end

  # @!visibility private
  # @!macro internal_implementation_note
  class RubyThreadLocalVar < AbstractThreadLocalVar

    # Each thread has a (lazily initialized) array of thread-local variable values
    # Each time a new thread-local var is created, we allocate an "index" for it
    # For example, if the allocated index is 1, that means slot #1 in EVERY
    #   thread's thread-local array will be used for the value of that TLV
    #
    # The good thing about using a per-THREAD structure to hold values, rather
    #   than a per-TLV structure, is that no synchronization is needed when
    #    reading and writing those values (since the structure is only ever
    #    accessed by a single thread)
    #
    # Of course, when a TLV is GC'd, 1) we need to recover its index for use
    #   by other new TLVs (otherwise the thread-local arrays could get bigger
    #   and bigger with time), and 2) we need to null out all the references
    #   held in the now-unused slots (both to avoid blocking GC of those objects,
    #   and also to prevent "stale" values from being passed on to a new TLV
    #   when the index is reused)
    # Because we need to null out freed slots, we need to keep references to
    #   ALL the thread-local arrays -- ARRAYS is for that
    # But when a Thread is GC'd, we need to drop the reference to its thread-local
    #   array, so we don't leak memory

    # @!visibility private
    FREE = []
    LOCK = Mutex.new
    ARRAYS = {} # used as a hash set
    @@next = 0
    private_constant :FREE, :LOCK, :ARRAYS

    # @!macro [attach] thread_local_var_method_initialize
    #
    #   Creates a thread local variable.
    #
    #   @param [Object] default the default value when otherwise unset
    def initialize(default = nil)
      @default = default
      allocate_storage
    end

    # @!macro thread_local_var_method_get
    def value
      if array = get_threadlocal_array
        value = array[@index]
        if value.nil?
          @default
        elsif value.equal?(NIL_SENTINEL)
          nil
        else
          value
        end
      else
        @default
      end
    end

    # @!macro thread_local_var_method_set
    def value=(value)
      me = Thread.current
      # We could keep the thread-local arrays in a hash, keyed by Thread
      # But why? That would require locking
      # Using Ruby's built-in thread-local storage is faster
      unless array = get_threadlocal_array(me)
        array = set_threadlocal_array([], me)
        LOCK.synchronize { ARRAYS[array.object_id] = array }
        ObjectSpace.define_finalizer(me, self.class.thread_finalizer(array))
      end
      array[@index] = (value.nil? ? NIL_SENTINEL : value)
      value
    end

    # @!macro thread_local_var_method_bind
    def bind(value, &block)
      if block_given?
        old_value = self.value
        begin
          self.value = value
          yield
        ensure
          self.value = old_value
        end
      end
    end

    protected

    # @!visibility private
    def allocate_storage
      @index = LOCK.synchronize do
        FREE.pop || begin
        result = @@next
        @@next += 1
        result
        end
      end
      ObjectSpace.define_finalizer(self, self.class.threadlocal_finalizer(@index))
    end

    # @!visibility private
    def self.threadlocal_finalizer(index)
      proc do
        LOCK.synchronize do
          FREE.push(index)
          # The cost of GC'ing a TLV is linear in the number of threads using TLVs
          # But that is natural! More threads means more storage is used per TLV
          # So naturally more CPU time is required to free more storage
          ARRAYS.each_value do |array|
            array[index] = nil
          end
        end
      end
    end

    # @!visibility private
    def self.thread_finalizer(array)
      proc do
        LOCK.synchronize do
          # The thread which used this thread-local array is now gone
          # So don't hold onto a reference to the array (thus blocking GC)
          ARRAYS.delete(array.object_id)
        end
      end
    end

    private

    if Thread.instance_methods.include?(:thread_variable_get)

      def get_threadlocal_array(thread = Thread.current)
        thread.thread_variable_get(:__threadlocal_array__)
      end

      def set_threadlocal_array(array, thread = Thread.current)
        thread.thread_variable_set(:__threadlocal_array__, array)
      end

    else

      def get_threadlocal_array(thread = Thread.current)
        thread[:__threadlocal_array__]
      end

      def set_threadlocal_array(array, thread = Thread.current)
        thread[:__threadlocal_array__] = array
      end
    end

    # This exists only for use in testing
    # @!visibility private
    def value_for(thread)
      if array = get_threadlocal_array(thread)
        value = array[@index]
        if value.nil?
          @default
        elsif value.equal?(NIL_SENTINEL)
          nil
        else
          value
        end
      else
        @default
      end
    end
  end

  if Concurrent.on_jruby?

    # @!visibility private
    # @!macro internal_implementation_note
    class JavaThreadLocalVar < AbstractThreadLocalVar

      # @!macro thread_local_var_method_get
      def value
        value = @var.get

        if value.nil?
          @default
        elsif value == NIL_SENTINEL
          nil
        else
          value
        end
      end

      # @!macro thread_local_var_method_set
      def value=(value)
        @var.set(value)
      end

      # @!macro thread_local_var_method_bind
      def bind(value, &block)
        if block_given?
          old_value = @var.get
          begin
            @var.set(value)
            yield
          ensure
            @var.set(old_value)
          end
        end
      end

      protected

      # @!visibility private
      def allocate_storage
        @var = java.lang.ThreadLocal.new
      end
    end
  end

  # @!visibility private
  # @!macro internal_implementation_note
  ThreadLocalVarImplementation = case
                                 when Concurrent.on_jruby?
                                   JavaThreadLocalVar
                                 else
                                   RubyThreadLocalVar
                                 end
  private_constant :ThreadLocalVarImplementation

  # @!macro thread_local_var
  class ThreadLocalVar < ThreadLocalVarImplementation

    # @!method initialize(default = nil)
    #   @!macro thread_local_var_method_initialize

    # @!method value
    #   @!macro thread_local_var_method_get

    # @!method value=(value)
    #   @!macro thread_local_var_method_set

    # @!method bind(value, &block)
    #   @!macro thread_local_var_method_bind

  end
end
