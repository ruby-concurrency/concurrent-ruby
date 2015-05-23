module Concurrent
  module Actor
    module Behaviour
      # Delegates messages and events to {AbstractContext} instance
      class ExecutesContext < Abstract
        def on_envelope(envelope)
          context.on_envelope envelope
        end

        def on_event(event)
          context.on_event(event)
          core.log DEBUG, "event: #{event.inspect}"
          super event
        end
      end
    end
  end
end
