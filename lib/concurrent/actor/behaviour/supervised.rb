module Concurrent
  module Actor
    module Behaviour

      # Sets and holds the supervisor of the actor if any. There is at most one supervisor
      # for each actor. Each supervisor is automatically linked. Messages:
      # `:pause!, :resume!, :reset!, :restart!` are accepted only from supervisor.
      #
      #     actor    = AdHoc.spawn(name: 'supervisor', behaviour_definition: Behaviour.restarting_behaviour_definition) do
      #       child = AdHoc.spawn(name: 'supervised', behaviour_definition: Behaviour.restarting_behaviour_definition) do
      #         p 'restarted'
      #         # message handle of supervised
      #         -> message { raise 'failed' }
      #       end
      #       # supervise the child
      #       child << :supervise
      #
      #       # message handle of supervisor
      #       -> message do
      #         child << message if message != :reset
      #       end
      #     end
      #
      #     actor << :bug
      #     # will be delegated to 'supervised', 'supervised' fails and is reset by its 'supervisor'
      #
      class Supervised < Abstract
        attr_reader :supervisor

        def initialize(core, subsequent, core_options)
          super core, subsequent, core_options

          @supervisor = if core_options[:supervise] != false
                          Actor.current
                        else
                          nil
                        end
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

        def on_event(public, event)
          @supervisor = nil if event == :terminated
          super public, event
        end
      end
    end
  end
end
