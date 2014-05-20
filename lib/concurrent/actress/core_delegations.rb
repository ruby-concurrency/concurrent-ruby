module Concurrent
  module Actress

    # delegates publicly expose-able methods calls to Core
    module CoreDelegations
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

      alias_method :ref, :reference
    end
  end
end
