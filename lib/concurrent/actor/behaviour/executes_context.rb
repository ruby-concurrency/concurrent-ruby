module Concurrent
  module Actor
    module Behaviour
      class ExecutesContext < Abstract
        def on_envelope(envelope)
          context.on_envelope envelope
        end

        def on_event(event)
          context.on_event(event)
          super event
        end
      end
    end
  end
end
