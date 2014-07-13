module Concurrent
  module Actor
    module InternalDelegations
      include PublicDelegations

      # @see Core#children
      def children
        core.children
      end

      # @see Core#terminate!
      def terminate!
        core.terminate!
      end

      # delegates to core.log
      # @see Logging#log
      def log(level, message = nil, &block)
        core.log(level, message, &block)
      end

      def dead_letter_routing
        context.dead_letter_routing
      end

      def redirect(reference, envelope = self.envelope)
        reference.message(envelope.message, envelope.ivar)
        Behaviour::MESSAGE_PROCESSED
      end

      def context
        core.context
      end

      def behaviour(behaviour_class)
        core.behaviour(behaviour_class)
      end

      def behaviour!(behaviour_class)
        core.behaviour!(behaviour_class)
      end

    end
  end
end
