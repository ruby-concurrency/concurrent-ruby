module Concurrent

  module AtomicNumericCompareAndSetWrapper
    #alias _compare_and_set compare_and_set

    def compare_and_set(expected, new)
      if expected.kind_of? Numeric
        while true
          old = get

          return false unless old.kind_of? Numeric

          return false unless old == expected

          result = _compare_and_set(old, new)
          return result if result
        end
      else
        _compare_and_set(expected, new)
      end
    end
    alias compare_and_swap compare_and_set
  end
end
