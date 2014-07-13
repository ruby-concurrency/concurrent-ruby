module Concurrent
  module Actor
    module Behaviour
      # Simply fails when message arrives here.
      class ErrorsOnUnknownMessage < Abstract
        def on_envelope(envelope)
          raise UnknownMessage, envelope
        end
      end
    end
  end
end
