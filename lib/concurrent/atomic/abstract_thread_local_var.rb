module Concurrent

  # @!macro thread_local_var
  # @!macro internal_implementation_note
  # @!visibility private
  class AbstractThreadLocalVar

    # @!visibility private
    NIL_SENTINEL = Object.new
    private_constant :NIL_SENTINEL

    # @!macro thread_local_var_method_initialize
    def initialize(default = nil)
      @default = default
      allocate_storage
    end

    # @!macro thread_local_var_method_get
    def value
      raise NotImplementedError
    end

    # @!macro thread_local_var_method_set
    def value=(value)
      raise NotImplementedError
    end

    # @!macro thread_local_var_method_bind
    def bind(value, &block)
      raise NotImplementedError
    end

    protected

    # @!visibility private
    def allocate_storage
      raise NotImplementedError
    end
  end
end
