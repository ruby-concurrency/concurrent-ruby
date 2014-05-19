module Concurrent

  class MutexAtomic

    def initialize(init = nil)
      @value = init
      @mutex = Mutex.new
    end

    def value
      @mutex.lock
      @value
    ensure
      @mutex.unlock
    end

    def value=(value)
      @mutex.lock
      @value = value
    ensure
      @mutex.unlock
    end

    def modify
      @mutex.lock
      result = yield @value
      @value = result
    ensure
      @mutex.unlock
    end

    def compare_and_set(expect, update)
      @mutex.lock
      if @value == expect
        @value = update
        true
      else
        false
      end
    ensure
      @mutex.unlock
    end
  end

  class Atomic < MutexAtomic
  end

end
