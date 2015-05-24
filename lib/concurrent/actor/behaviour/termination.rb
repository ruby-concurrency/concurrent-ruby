module Concurrent
  module Actor
    module Behaviour

      # Handles actor termination.
      # @note Actor rejects envelopes when terminated.
      # @note TODO missing example
      class Termination < Abstract

        # @!attribute [r] terminated
        #   @return [Edge::Event] event which will become set when actor is terminated.
        attr_reader :terminated

        def initialize(core, subsequent, core_options)
          super core, subsequent, core_options
          @terminated = Concurrent.event
        end

        # @note Actor rejects envelopes when terminated.
        # @return [true, false] if actor is terminated
        def terminated?
          @terminated.completed?
        end

        def on_envelope(envelope)
          case envelope.message
          when :terminated?
            terminated?
          when :terminate!
            terminate!
          when :terminated_event # TODO rename to :termination_event
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
          terminated.complete
          broadcast(true, :terminated) # TODO do not end up in Dead Letter Router
          parent << :remove_child if parent
          true
        end
      end
    end
  end
end
