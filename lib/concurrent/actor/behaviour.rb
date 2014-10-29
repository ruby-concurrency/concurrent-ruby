module Concurrent
  module Actor

    # Actors have modular architecture, which is achieved by combining a light core with chain of
    # behaviours. Each message or internal event propagates through the chain allowing the
    # behaviours react based on their responsibility. listing few as an example:
    #
    # -   {Behaviour::Linking}:
    #
    #     > {include:Actor::Behaviour::Linking}
    #
    # -   {Behaviour::Awaits}:
    #
    #     > {include:Actor::Behaviour::Awaits}
    #
    # See {Behaviour}'s namespace fo other behaviours.
    # If needed new behaviours can be added, or old one removed to get required behaviour.
    module Behaviour
      MESSAGE_PROCESSED = Object.new

      require 'concurrent/actor/behaviour/abstract'
      require 'concurrent/actor/behaviour/awaits'
      require 'concurrent/actor/behaviour/buffer'
      require 'concurrent/actor/behaviour/errors_on_unknown_message'
      require 'concurrent/actor/behaviour/executes_context'
      require 'concurrent/actor/behaviour/linking'
      require 'concurrent/actor/behaviour/pausing'
      require 'concurrent/actor/behaviour/removes_child'
      require 'concurrent/actor/behaviour/sets_results'
      require 'concurrent/actor/behaviour/supervised'
      require 'concurrent/actor/behaviour/supervising'
      require 'concurrent/actor/behaviour/termination'
      require 'concurrent/actor/behaviour/terminates_children'

      def self.basic_behaviour_definition
        [*base(:terminate!),
         *linking,
         *user_messages]
      end

      def self.restarting_behaviour_definition(handle = :reset!, strategy = :one_for_one)
        [*base(:pause!),
         *linking,
         *supervised,
         *supervising(handle, strategy),
         *user_messages]
      end

      def self.base(on_error)
        [[SetResults, [on_error]],
         # has to be before Termination to be able to remove children form terminated actor
         [RemovesChild, []],
         [Termination, []],
         [TerminatesChildren, []]]
      end

      # @see '' its source code
      def self.linking
        [[Linking, []]]
      end

      def self.supervised
        [[Supervised, []],
         [Pausing, []]]
      end

      def self.supervising(handle = :reset!, strategy = :one_for_one)
        [[Behaviour::Supervising, [handle, strategy]]]
      end

      def self.user_messages
        [[Awaits, []],
         [ExecutesContext, []],
         [ErrorsOnUnknownMessage, []]]
      end
    end
  end
end
