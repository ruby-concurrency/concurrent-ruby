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

      def reference
        core.reference
      end

      def executor
        core.executor
      end

      alias_method :ref, :reference
    end
  end
end
