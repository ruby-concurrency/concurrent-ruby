require 'concurrent/atomic/abstract_thread_local_var'

module Concurrent
  # Has the same interface as {ThreadLocalVar} but the value can never be changed.
  # The value is always the default provided to the constructor.
  class ConstantThreadLocalVar < AbstractThreadLocalVar

    # @note the value is always equal to default value
    # @!macro thread_local_var_method_get
    def value
      default
    end

    # @!macro thread_local_var_method_set
    # @raise ArgumentError if the value is not equal to the default
    def value=(value)
      if value != default
        raise ArgumentError, "Constant thread local vars may not be altered"
      end
    end

    # @!macro thread_local_var_method_bind
    # @raise ArgumentError if the value is not equal to the default
    def bind(value)
      self.value = value
      if block_given?
        yield
      end
    end

    protected

    def allocate_storage
      # nothing to do
    end

    def default
      if @default_block
        @default_block.call
      else
        @default
      end
    end
  end
end
