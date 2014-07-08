module Concurrent
  module Actor

    # Provides publicly expose-able methods from {Core}.
    module CoreDelegations
      def name
        core.name
      end

      def path
        core.path
      end

      def parent
        core.parent
      end

      def terminated?
        core.terminated?
      end

      def terminated
        core.terminated
      end

      def reference
        core.reference
      end

      def executor
        core.executor
      end

      def context_class
        core.context_class
      end

      alias_method :ref, :reference
      alias_method :actor_class, :context_class
    end
  end
end
