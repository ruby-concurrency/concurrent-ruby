require 'thread'
module Concurrent
  class Channel
    module Runtime
      module_function

      GOROUTINE = Thread

      def go(prc, *args)
        GOROUTINE.new { prc.call(*args) }
      end

      def current
        GOROUTINE.current
      end
    end
  end
end
