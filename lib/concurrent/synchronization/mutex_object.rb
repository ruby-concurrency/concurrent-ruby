module Concurrent
  module Synchronization
    class MutexObject < AbstractObject
      def initialize(*args, &block)
        @__lock__      = ::Mutex.new
        @__condition__ = ::ConditionVariable.new
        synchronize { ns_initialize(*args, &block) }
      end

      protected

      def synchronize
        if @__lock__.owned?
          yield
        else
          @__lock__.synchronize { yield }
        end
      end

      def ns_signal
        @__condition__.signal
        self
      end

      def ns_broadcast
        @__condition__.broadcast
        self
      end

      def ns_wait(timeout = nil)
        @__condition__.wait @__lock__, timeout
        self
      end

      def ensure_ivar_visibility!
        # relying on undocumented behavior of CRuby, GVL acquire has lock which ensures visibility of ivars
        # https://github.com/ruby/ruby/blob/ruby_2_2/thread_pthread.c#L204-L211
      end
    end
  end
end
