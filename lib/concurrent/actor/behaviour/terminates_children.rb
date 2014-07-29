module Concurrent
  module Actor
    module Behaviour
      # Terminates all children when the actor terminates.
      class TerminatesChildren < Abstract
        def on_event(event)
          children.each { |ch| ch << :terminate! } if event == :terminated
          super event
        end
      end
    end
  end
end
