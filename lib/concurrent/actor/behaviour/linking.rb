module Concurrent
  module Actor
    module Behaviour

      # Links the actor to other actors and sends actor's events to them,
      # like: `:terminated`, `:paused`, errors, etc
      # TODO example
      class Linking < Abstract
        def initialize(core, subsequent)
          super core, subsequent
          @linked = Set.new
        end

        def on_envelope(envelope)
          case envelope.message
          when :link
            link envelope.sender
          when :unlink
            unlink envelope.sender
          when :linked?
            @linked.include? envelope.sender
          else
            pass envelope
          end
        end

        def link(ref)
          @linked.add(ref)
          true
        end

        def unlink(ref)
          @linked.delete(ref)
          true
        end

        def on_event(event)
          @linked.each { |a| a << event }
          @linked.clear if event == :terminated
          super event
        end
      end
    end
  end
end
