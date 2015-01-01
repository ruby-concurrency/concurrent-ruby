module Concurrent
  module Actor
    module Behaviour

      # Allows to pause actors on errors.
      # When paused all arriving messages are collected and processed after the actor
      # is resumed or reset. Resume will simply continue with next message.
      # Reset also reinitialized context.
      # @note TODO missing example
      class Pausing < Abstract
        def initialize(core, subsequent, core_options)
          super core, subsequent, core_options
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
          do_pause
          broadcast true, error || :paused
          true
        end

        def resume!
          do_resume
          broadcast(true, :resumed)
          true
        end

        def reset!
          broadcast(false, :resetting)
          do_reset
          broadcast(true, :reset)
          true
        end

        def restart!
          broadcast(false, :restarting)
          do_restart
          broadcast(true, :restarted)
          true
        end

        def on_event(public, event)
          reject_buffer if event == :terminated
          super public, event
        end

        private

        def do_pause
          @paused = true
          nil
        end

        def do_resume
          @paused = false
          reschedule_buffer
          nil
        end

        def do_reset
          rebuild_context
          do_resume
          reschedule_buffer
          nil
        end

        def do_restart
          rebuild_context
          reject_buffer
          do_resume
          nil
        end

        def rebuild_context
          core.allocate_context
          core.build_context
          nil
        end

        def reschedule_buffer
          @buffer.each { |envelope| core.schedule_execution { core.process_envelope envelope } }
          @buffer.clear
        end

        def reject_buffer
          @buffer.each { |envelope| reject_envelope envelope }
          @buffer.clear
        end
      end
    end
  end
end
