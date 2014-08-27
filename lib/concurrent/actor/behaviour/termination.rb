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
          case envelope.message
          when :terminated?
            terminated?
          when :terminate!
            terminate!
          when :terminated_event
            terminated
          else
            if terminated?
              reject_envelope envelope
              MESSAGE_PROCESSED
            else
              pass envelope
            end
          end
        end

        # Terminates the actor. Any Envelope received after termination is rejected.
        # Terminates all its children, does not wait until they are terminated.
        def terminate!
          return true if terminated?
          terminated.set
          broadcast(:terminated) # TODO do not end up in Dead Letter Router
          parent << :remove_child if parent
          true
        end
      end
    end
  end
end
