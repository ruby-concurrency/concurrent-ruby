module Concurrent
  module Actor
    module Behaviour

      # Allows to pause actors on errors.
      # When paused all arriving messages are collected and processed after the actor
      # is resumed or reset. Resume will simply continue with next message.
      # Reset also reinitialized context. `:reset!` and `:resume!` messages are only accepted
      # form supervisor, see Supervised behaviour.
      class Pausing < Abstract
        def initialize(core, subsequent)
          super core, subsequent
          @paused = false
          @buffer = []
        end

        def on_envelope(envelope)
          case envelope.message
          when :pause!
            from_supervisor?(envelope) { pause! }
          when :resume!
            from_supervisor?(envelope) { resume! }
          when :reset!
            from_supervisor?(envelope) { reset! }
          when :restart!
            from_supervisor?(envelope) { restart! }
          else
            if @paused
              @buffer << envelope
              MESSAGE_PROCESSED
            else
              pass envelope
            end
          end
        end

        def from_supervisor?(envelope)
          if behaviour!(Supervised).supervisor == envelope.sender
            yield
          else
            false
          end
        end

        def pause!(error = nil)
          @paused = true
          broadcast(error || :paused)
          true
        end

        def resume!(broadcast = true)
          @paused = false
          broadcast(:resumed) if broadcast
          true
        end

        def reset!(broadcast = true)
          core.allocate_context
          core.build_context
          resume!(false)
          broadcast(:reset) if broadcast
          true
        end

        def restart!
          reset! false
          broadcast(:restarted)
          true
        end

        def on_event(event)
          case event
          when :terminated, :restarted
            @buffer.each { |envelope| reject_envelope envelope }
            @buffer.clear
          when :resumed, :reset
            @buffer.each { |envelope| core.schedule_execution { pass envelope } }
            @buffer.clear
          end
          super event
        end
      end
    end
  end
end
