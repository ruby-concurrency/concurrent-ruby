require 'concurrent/atomic'

module Concurrent

  module ThreadLocalRubyStorage

    protected

    def allocate_storage
      @storage = Atomic.new Hash.new
    end

    def get
      @storage.get[Thread.current.object_id]
    end

    def set(value, &block)
      key = Thread.current.object_id

      @storage.update do |s|
        s.merge(key => value)
      end

      if block_given?
        begin
          block.call
        ensure
          @storage.update do |s|
            s.clone.tap { |h| h.delete key }
          end
        end

      else
        unless ThreadLocalRubyStorage.i_know_it_may_leak_values?
          warn "it may leak values if used without block\n#{caller[0]}"
        end
      end
    end

    def self.i_know_it_may_leak_values!
      @leak_acknowledged = true
    end

    def self.i_know_it_may_leak_values?
      @leak_acknowledged
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

    # may leak the value, #bind is preferred
    def value=(value)
      bind value
    end

    def bind(value, &block)
      if value.nil?
        stored_value = NIL_SENTINEL
      else
        stored_value = value
      end

      set stored_value, &block

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
