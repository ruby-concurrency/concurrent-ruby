module Concurrent
  module Actor
    module Behaviour

      # Sets and holds the supervisor of the actor if any. There is at most one supervisor
      # for each actor. Each supervisor is automatically linked. Messages:
      # `:pause!, :resume!, :reset!, :restart!` are accepted only from supervisor.
      class Supervised < Abstract
        attr_reader :supervisor

        def initialize(core, subsequent)
          super core, subsequent
          @supervisor = nil
        end

        def on_envelope(envelope)
          case envelope.message
          when :supervise
            supervise envelope.sender
          when :supervisor
            supervisor
          when :un_supervise
            un_supervise envelope.sender
          when :pause!, :resume!, :reset!, :restart!
            # allow only supervisor to control the actor
            if @supervisor == envelope.sender
              pass envelope
            else
              false
            end
          else
            pass envelope
          end
        end

        def supervise(ref)
          @supervisor = ref
          behaviour!(Linking).link ref
          true
        end

        def un_supervise(ref)
          if @supervisor == ref
            behaviour!(Linking).unlink ref
            @supervisor = nil
            true
          else
            false
          end
        end

        def on_event(event)
          @supervisor = nil if event == :terminated
          super event
        end
      end
    end
  end
end
