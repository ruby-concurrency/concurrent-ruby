module Concurrent
  module Actor
    module Behaviour
      class Abstract
        include TypeCheck
        include InternalDelegations

        attr_reader :core, :subsequent

        def initialize(core, subsequent)
          @core       = Type! core, Core
          @subsequent = Type! subsequent, Abstract, NilClass
        end

        def on_envelope(envelope)
          pass envelope
        end

        def pass(envelope)
          subsequent.on_envelope envelope
        end

        def on_event(event)
          subsequent.on_event event if subsequent
        end

        def broadcast(event)
          core.broadcast(event)
        end

        def reject_envelope(envelope)
          envelope.reject! ActorTerminated.new(reference)
          dead_letter_routing << envelope unless envelope.ivar
          log Logging::DEBUG, "rejected #{envelope.message} from #{envelope.sender_path}"
        end
      end
    end
  end
end

