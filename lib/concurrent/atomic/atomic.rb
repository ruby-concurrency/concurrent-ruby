module Concurrent

  class MutexAtomic

    def initialize(init = nil)
      @value = init
      @mutex = Mutex.new
    end

    def value
      @mutex.lock
      result = @value
      @mutex.unlock

      result
    end

    def value=(value)
      @mutex.lock
      result = @value = value
      @mutex.unlock

      result
    end

    def modify
      @mutex.lock
      result = yield @value
      @value = result
      @mutex.unlock

      result
    end

    def compare_and_set(expect, update)
      @mutex.lock
      if @value == expect
        @value = update
        result = true
      else
        result = false
      end
      @mutex.unlock

      result
    end
  end

  class Atomic < MutexAtomic
  end

end
