module Concurrent
  module Actor
    module Behaviour
      # Terminates all children when the actor terminates.
      class TerminatesChildren < Abstract
        def on_event(public, event)
          event_name, _ = event
          children.map { |ch| ch << :terminate! } if event_name == :terminated
          super public, event
        end
      end
    end
  end
end
