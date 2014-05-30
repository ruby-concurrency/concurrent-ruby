module Concurrent

  class Atomic
    class ConcurrentUpdateError < ThreadError
      # frozen pre-allocated backtrace to speed ConcurrentUpdateError
      CONC_UP_ERR_BACKTRACE = ['backtrace elided; set verbose to enable'].freeze
    end
  end
end
