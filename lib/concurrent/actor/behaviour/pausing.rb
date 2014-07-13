module Concurrent
  module Actor
    module Behaviour
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
            # when :restart! TODO
            #   from_supervisor?(envelope) { reset! }
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

        def resume!
          @buffer.each { |envelope| core.schedule_execution { pass envelope } }
          @buffer.clear
          @paused = false
          broadcast(:resumed)
          true
        end

        def from_supervisor?(envelope)
          if behaviour!(Supervising).supervisor == envelope.sender
            yield
          else
            false
          end
        end

        def reset!
          core.allocate_context
          core.build_context
          broadcast(:reset)
          resume!
          true
        end

        def on_event(event)
          if event == :terminated
            @buffer.each { |envelope| reject_envelope envelope }
            @buffer.clear
          end
          super event
        end
      end
    end
  end
end
