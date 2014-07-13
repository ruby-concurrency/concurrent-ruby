module Concurrent
  module Actor
    module Behaviour
      class ErrorsOnUnknownMessage < Abstract
        def on_envelope(envelope)
          raise UnknownMessage, envelope
        end
      end
    end
  end
end
