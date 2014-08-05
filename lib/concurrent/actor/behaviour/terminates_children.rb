module Concurrent
  module Actor
    module Behaviour
      # Terminates all children when the actor terminates.
      class TerminatesChildren < Abstract
        def on_event(event)
          children.map { |ch| ch.ask :terminate! }.each(&:wait) if event == :terminated
          super event
        end
      end
    end
  end
end
