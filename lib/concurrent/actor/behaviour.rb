module Concurrent
  module Actor

    # TODO document dependencies
    # TODO callbacks to context
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
      require 'concurrent/actor/behaviour/supervising'
      require 'concurrent/actor/behaviour/termination'
      require 'concurrent/actor/behaviour/terminates_children'

      def self.basic_behaviour
        [*base,
         *user_messages(:terminate)]
      end

      def self.restarting_behaviour
        [*base,
         *supervising,
         *user_messages(:pause)]
      end

      def self.base
        [[SetResults, [:terminate]],
         # has to be before Termination to be able to remove children form terminated actor
         [RemovesChild, []],
         [Termination, []],
         [TerminatesChildren, []],
         [Linking, []]]
      end

      def self.supervising
        [[Supervising, []],
         [Pausing, []]]
      end

      def self.user_messages(on_error)
        [[Buffer, []],
         [SetResults, [on_error]],
         [Awaits, []],
         [ExecutesContext, []],
         [ErrorsOnUnknownMessage, []]]
      end
    end
  end
end
