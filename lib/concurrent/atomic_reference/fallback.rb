require 'thread'
require 'concurrent/atomic_reference/direct_update'

module Concurrent

  # Portable/generic (but not very memory or scheduling-efficient) fallback
  class Atomic #:nodoc: all
    def initialize(value = nil)
      @mutex = Mutex.new
      @value = value
    end

    def get
      @mutex.synchronize { @value }
    end
    alias value get

    def set(new_value)
      @mutex.synchronize { @value = new_value }
    end
    alias value= set

    def get_and_set(new_value)
      @mutex.synchronize do
        old_value = @value
        @value = new_value
        old_value
      end
    end
    alias swap get_and_set

    def compare_and_set(old_value, new_value)
      return false unless @mutex.try_lock
      begin
        return false unless @value.equal? old_value
        @value = new_value
      ensure
        @mutex.unlock
      end
      true
    end

    require 'concurrent/atomic_reference/numeric_cas_wrapper'
  end
end
