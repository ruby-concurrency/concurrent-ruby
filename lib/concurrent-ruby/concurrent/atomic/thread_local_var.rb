require 'concurrent/constants'

module Concurrent

  # @!macro thread_local_var
  class ThreadLocalVar
    # @!macro thread_local_var_method_initialize
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

      @name = :"concurrent_variable_#{object_id}"
    end

    # @!macro thread_local_var_method_get
    def value
      value = Thread.current.thread_variable_get(@name)

      if value.nil?
        default
      elsif value.equal?(NULL)
        nil
      else
        value
      end
    end

    # @!macro thread_local_var_method_set
    def value=(value)
      if value.nil?
        value = NULL
      end

      Thread.current.thread_variable_set(@name, value)
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
