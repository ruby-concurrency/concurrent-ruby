require 'concurrent/atomic/abstract_thread_local_var'

module Concurrent
  class ConstantThreadLocalVar < AbstractThreadLocalVar
    def value
      default
    end

    def value=(value)
      if value != default
        raise ArgumentError, "Constant thread local vars may not be altered"
      end
    end

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
