module Concurrent
  module Actor
    module Behaviour

      # Handles actor termination.
      # @note Actor rejects envelopes when terminated.
      # @note TODO missing example
      class Termination < Abstract

        # @!attribute [r] terminated
        #   @return [Edge::Event] event which will become set when actor is terminated.
        # @!attribute [r] reason
        attr_reader :terminated, :reason

        def initialize(core, subsequent, core_options, trapping = false)
          super core, subsequent, core_options
          @terminated        = Concurrent.event
          @public_terminated = @terminated.hide_completable
          @reason            = nil
          @trapping          = trapping
        end

        # @note Actor rejects envelopes when terminated.
        # @return [true, false] if actor is terminated
        def terminated?
          @terminated.completed?
        end

        def trapping?
          @trapping
        end

        def trapping=(val)
          @trapping = !!val
        end

        def on_envelope(envelope)
          command, reason = envelope.message
          case command
          when :terminated?
            terminated?
          when :terminate!
            if trapping? && reason != :kill
              pass envelope
            else
              terminate! reason
            end
          when :termination_event
            @public_terminated
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
        def terminate!(reason = :normal)
          # TODO return after all children are terminated
          return true if terminated?
          @reason = reason
          terminated.complete
          broadcast(true, [:terminated, reason]) # TODO do not end up in Dead Letter Router
          parent << :remove_child if parent
          true
        end
      end
    end
  end
end
