module Concurrent
  module Actor
    module Behaviour
      class Awaits < Abstract
        def on_envelope(envelope)
          if envelope.message == :await
            true
          else
            pass envelope
          end
        end
      end
    end
  end
end
