require 'concurrent/constants'
require_relative 'locals'

module Concurrent

  # @!macro thread_local_var
  class ThreadLocalVar
    LOCALS = ThreadLocals.new(:concurrent_fiber_local_var)

    # @!macro thread_local_var_method_initialize
    #
    #   Creates a thread local variable.
    #
    #   @param [Object] default the default value when otherwise unset
    #   @param [Proc] default_block Optional block that gets called to obtain the
    #     default value for each thread

    # @!macro thread_local_var_method_get
    #
    #   Returns the value in the current thread's copy of this thread-local variable.
    #
    #   @return [Object] the current value

    # @!macro thread_local_var_method_set
    #
    #   Sets the current thread's copy of this thread-local variable to the specified value.
    #
    #   @param [Object] value the value to set
    #   @return [Object] the new value

    # @!macro thread_local_var_method_bind
    #
    #   Bind the given value to thread local storage during
    #   execution of the given block.
    #
    #   @param [Object] value the value to bind
    #   @yield the operation to be performed with the bound variable
    #   @return [Object] the value

    def initialize(default = nil, &default_block)
      if default && block_given?
        raise ArgumentError, "Cannot use both value and block as default value"
      end

      if block_given?
        @default_block = default_block
        @default = nil
      else
        @default_block = nil
        @default = default
      end

      @index = LOCALS.next_index(self)
    end

    # @!macro thread_local_var_method_get
    def value
      LOCALS.fetch(@index) {default}
    end

    # @!macro thread_local_var_method_set
    def value=(value)
      LOCALS.set(@index, value)
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
    def default
      if @default_block
        self.value = @default_block.call
      else
        @default
      end
    end
  end
end
