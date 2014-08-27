module Concurrent
  module Actor
    module Behaviour

      # Allows to pause actors on errors.
      # When paused all arriving messages are collected and processed after the actor
      # is resumed or reset. Resume will simply continue with next message.
      # Reset also reinitialized context.
      # TODO example
      class Pausing < Abstract
        def initialize(core, subsequent)
          super core, subsequent
          @paused = false
          @buffer = []
        end

        def on_envelope(envelope)
          case envelope.message
          when :pause!
            pause!
          when :resume!
            resume!
          when :reset!
            reset!
          when :restart!
            restart!
          else
            if @paused
              @buffer << envelope
              MESSAGE_PROCESSED
            else
              pass envelope
            end
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
