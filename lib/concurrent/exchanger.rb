module Concurrent
  class Exchanger

    EMPTY = Object.new

    def initialize(opts = {})
      @first = MVar.new(EMPTY, opts)
      @second = MVar.new(MVar::EMPTY, opts)
    end

    def exchange(value, timeout = nil)
      first = @first.take(timeout)
      if first == MVar::TIMEOUT
        nil
      elsif first == EMPTY
        @first.put value
        second = @second.take timeout
        if second == MVar::TIMEOUT
          nil
        else
          second
        end
      else
        @first.put EMPTY
        @second.put value
        first
      end
    end

  end
end
