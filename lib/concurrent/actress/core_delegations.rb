module Concurrent
  module Actress

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

      def actor_class
        core.actor_class
      end

      alias_method :ref, :reference
      alias_method :actress_class, :actor_class
    end
  end
end
