module Concurrent
  module Actor
    module Behaviour

      # Handles actor termination.
      # @note Actor rejects envelopes when terminated.
      class Termination < Abstract

        # @!attribute [r] terminated
        #   @return [Event] event which will become set when actor is terminated.
        attr_reader :terminated

        def initialize(core, subsequent)
          super core, subsequent
          @terminated = Event.new
        end

        # @note Actor rejects envelopes when terminated.
        # @return [true, false] if actor is terminated
        def terminated?
          @terminated.set?
        end

        def on_envelope(envelope)
          if terminated?
            reject_envelope envelope
            MESSAGE_PROCESSED
          else
            if envelope.message == :terminate!
              terminate!
            else
              pass envelope
            end
          end
        end

        # Terminates the actor. Any Envelope received after termination is rejected.
        # Terminates all its children, does not wait until they are terminated.
        def terminate!
          return nil if terminated?
          @terminated.set
          broadcast(:terminated)
          parent << :remove_child if parent
          nil
        end
      end
    end
  end
end
