module Concurrent
  class Exchanger

    EMPTY = Object.new

    def initialize(opts = {})
      @first = MVar.new(EMPTY, opts)
      @second = MVar.new(MVar::EMPTY, opts)
    end

    # @param [Object] value the value to exchange with an other thread
    # @param [Numeric] timeout the maximum time in second to wait for one other thread. nil (default value) means no timeout
    # @return [Object] the value exchanged by the other thread; nil if timed out
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
