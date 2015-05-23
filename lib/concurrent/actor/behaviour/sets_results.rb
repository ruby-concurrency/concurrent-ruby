module Concurrent
  module Actor
    module Behaviour
      # Collects returning value and sets the CompletableFuture in the {Envelope} or error on failure.
      class SetResults < Abstract
        attr_reader :error_strategy

        def initialize(core, subsequent, error_strategy)
          super core, subsequent
          @error_strategy = Match! error_strategy, :just_log, :terminate!, :pause!
        end

        def on_envelope(envelope)
          result = pass envelope
          if result != MESSAGE_PROCESSED && !envelope.future.nil?
            envelope.future.success result
          end
          nil
        rescue => error
          log ERROR, error
          case error_strategy
          when :terminate!
            terminate!
          when :pause!
            behaviour!(Pausing).pause!(error)
          when :just_log
            # nothing
          else
            raise
          end
          envelope.future.fail error unless envelope.future.nil?
        end
      end
    end
  end
end
