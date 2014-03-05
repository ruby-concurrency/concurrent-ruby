module Concurrent

  module ThreadLocalSymbolAllocator

    COUNTER = AtomicFixnum.new

    protected

    def allocate_symbol
      # Warning: this symbol may never be deallocated
      @symbol = :"thread_local_symbol_#{COUNTER.increment}"
    end

  end

  module ThreadLocalOldStorage

    include ThreadLocalSymbolAllocator

    protected

    def allocate_storage
      allocate_symbol
    end

    def get
      Thread.current[@symbol]
    end

    def set(value)
      Thread.current[@symbol] = value
    end

  end

  module ThreadLocalNewStorage

    include ThreadLocalSymbolAllocator

    protected

    def allocate_storage
      allocate_symbol
    end

    def get
      Thread.current.thread_variable_get(@symbol)
    end

    def set(value)
      Thread.current.thread_variable_set(@symbol, value)
    end

  end

  module ThreadLocalJavaStorage

    protected

    def allocate_storage
      @var = java.lang.ThreadLocal.new
    end

    def get
      @var.get
    end

    def set(value)
      @var.set(value)
    end

  end

  class ThreadLocalVar

    NIL_SENTINEL = Object.new

    if defined? java.lang
      include ThreadLocalJavaStorage
    elsif Thread.current.respond_to?(:thread_variable_set)
      include ThreadLocalNewStorage
    else
      include ThreadLocalOldStorage
    end

    def initialize(default = nil)
      @default = default
      allocate_storage
    end

    def value
      value = get

      if value.nil?
        @default
      elsif value == NIL_SENTINEL
        nil
      else
        value
      end
    end

    def value=(value)
      if value.nil?
        stored_value = NIL_SENTINEL
      else
        stored_value = value
      end

      set stored_value

      value
    end

  end

end
