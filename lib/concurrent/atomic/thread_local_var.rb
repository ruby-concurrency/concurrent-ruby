require 'concurrent/atomic'

module Concurrent

  module ThreadLocalRubyStorage

    def allocate_storage
      @storage = Atomic.new Hash.new
    end

    def get
      @storage.get[Thread.current]
    end

    def set(value)
      @storage.update { |s| s.merge Thread.current => value }
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

  class AbstractThreadLocalVar

    NIL_SENTINEL = Object.new

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

  class ThreadLocalVar < AbstractThreadLocalVar
    if RUBY_PLATFORM == 'java'
      include ThreadLocalJavaStorage
    else
      include ThreadLocalRubyStorage
    end
  end

end
