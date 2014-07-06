module Concurrent
  module Actress
    # implements the root actor
    class Root

      def initialize
        @dead_letter_router = DefaultDeadLetterHandler.spawn :default_dead_letter_handler
      end

      include Context
      # to allow spawning of new actors, spawn needs to be called inside the parent Actor
      def on_message(message)
        if message.is_a?(Array) && message.first == :spawn
          spawn message[1], &message[2]
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
