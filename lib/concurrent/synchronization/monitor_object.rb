module Concurrent
  module Synchronization
    class MonitorObject < MutexObject
      def initialize(*args, &block)
        @__lock__      = ::Monitor.new
        @__condition__ = @__lock__.new_cond
        synchronize { ns_initialize(*args, &block) }
      end

      protected

      def synchronize
        @__lock__.synchronize { yield }
      end

      def ns_wait(timeout = nil)
        @__condition__.wait timeout
        self
      end
    end
  end
end
