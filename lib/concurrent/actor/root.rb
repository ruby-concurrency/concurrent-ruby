module Concurrent
  module Actor
    # implements the root actor
    class Root

      include Context

      def initialize
        @dead_letter_router = Core.new(parent: reference,
                                       class:  DefaultDeadLetterHandler,
                                       name:   :default_dead_letter_handler).reference
      end

      # to allow spawning of new actors, spawn needs to be called inside the parent Actor
      def on_message(message)
        if message.is_a?(Array) && message.first == :spawn
          Actor.spawn message[1], &message[2]
        else
          # ignore
        end
      end

      def dead_letter_routing
        @dead_letter_router
      end
    end
  end
end
