module Concurrent
  module Synchronization
    class MonitorObject < MutexObject
      def initialize
        @__lock__do_not_use_directly      = ::Monitor.new
        @__condition__do_not_use_directly = @__lock__do_not_use_directly.new_cond
      end

      def synchronize
        @__lock__do_not_use_directly.synchronize { yield }
      end

      private

      def ns_wait(timeout = nil)
        @__condition__do_not_use_directly.wait timeout
        self
      end
    end
  end
end
