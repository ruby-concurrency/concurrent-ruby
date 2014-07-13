module Concurrent
  module Actor
    module Behaviour
      class ExecutesContext < Abstract
        def on_envelope(envelope)
          context.on_envelope envelope
        end
      end
    end
  end
end
