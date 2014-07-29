module Concurrent
  module Actor
    # implements the root actor
    class Root < AbstractContext

      def initialize
        # noinspection RubyArgCount
        @dead_letter_router = Core.new(parent:    reference,
                                       class:     DefaultDeadLetterHandler,
                                       supervise: true,
                                       name:      :default_dead_letter_handler).reference
      end

      # to allow spawning of new actors, spawn needs to be called inside the parent Actor
      def on_message(message)
        case
        when message.is_a?(Array) && message.first == :spawn
          Actor.spawn message[1], &message[2]
        when message == :dead_letter_routing
          @dead_letter_router
        else
          # ignore
        end
      end

      def dead_letter_routing
        @dead_letter_router
      end

      def behaviour_definition
        [*Behaviour.base,
         [Behaviour::Supervising, [:reset!, :one_for_one]],
         *Behaviour.user_messages(:just_log)]
      end
    end
  end
end
