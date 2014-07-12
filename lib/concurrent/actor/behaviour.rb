module Concurrent
  module Actor
    # TODO split this into files

    module ContextDelegations
      include CoreDelegations

      # @see Core#children
      def children
        core.children
      end

      # @see Core#terminate!
      def terminate!
        core.terminate!
      end

      # delegates to core.log
      # @see Logging#log
      def log(level, message = nil, &block)
        core.log(level, message, &block)
      end

      def dead_letter_routing
        context.dead_letter_routing
      end

      def redirect(reference, envelope = self.envelope)
        reference.message(envelope.message, envelope.ivar)
        Behaviour::NOT_PROCESSED
      end

      def context
        core.context
      end

      def broadcast(event)
        linking = core.behaviour(Behaviour::Linking) and
            linking.broadcast(event)
      end
    end

    module Behaviour
      NOT_PROCESSED = Object.new

      class Abstract
        include TypeCheck
        include ContextDelegations

        attr_reader :core, :subsequent

        def initialize(core, subsequent)
          @core       = Type! core, Core
          @subsequent = Type! subsequent, Abstract, NilClass
        end

        def on_message(message)
          raise NotImplementedError
        end

        def on_envelope(envelope)
          raise NotImplementedError
        end

        def pass(envelope)
          subsequent.on_envelope envelope
        end

        # TODO rename to on_terminate or something like that
        def reject_messages
          subsequent.reject_messages if subsequent
        end

        def reject_envelope(envelope)
          envelope.reject! ActorTerminated.new(reference)
          dead_letter_routing << envelope unless envelope.ivar
          log Logging::DEBUG, "rejected #{envelope.message} from #{envelope.sender_path}"

        end
      end

      class Termination < Abstract

        # @!attribute [r] terminated
        #   @return [Event] event which will become set when actor is terminated.
        attr_reader :terminated

        def initialize(core, subsequent)
          super core, subsequent
          @terminated = Event.new
        end

        # @note Actor rejects envelopes when terminated.
        # @return [true, false] if actor is terminated
        def terminated?
          @terminated.set?
        end

        def on_envelope(envelope)
          if terminated?
            reject_envelope envelope
            NOT_PROCESSED
          else
            if envelope.message == :terminate!
              terminate!
            else
              pass envelope
            end
          end
        end

        # Terminates the actor. Any Envelope received after termination is rejected.
        # Terminates all its children, does not wait until they are terminated.
        def terminate!
          return nil if terminated?
          children.each { |ch| ch << :terminate! }
          @terminated.set
          broadcast(:terminated)
          parent << :remove_child if parent
          core.reject_messages
          nil
        end
      end

      class Linking < Abstract
        def initialize(core, subsequent)
          super core, subsequent
          @linked = Set.new
        end

        def on_envelope(envelope)
          case envelope.message
          when :link
            @linked.add?(envelope.sender)
            true
          when :unlink
            @linked.delete(envelope.sender)
            true
          else
            pass envelope
          end
        end

        def reject_messages
          @linked.clear
          super
        end

        def broadcast(event)
          @linked.each { |a| a << event }
        end
      end

      class RemoveChild < Abstract
        def on_envelope(envelope)
          if envelope.message == :remove_child
            core.remove_child envelope.sender
          else
            pass envelope
          end
        end
      end

      class SetResults < Abstract
        def on_envelope(envelope)
          result = pass envelope
          if result != NOT_PROCESSED && !envelope.ivar.nil?
            envelope.ivar.set result
          end
          nil
        rescue => error
          log Logging::ERROR, error
          terminate!
          envelope.ivar.fail error unless envelope.ivar.nil?
        end
      end

      class Buffer < Abstract
        def initialize(core, subsequent)
          super core, SetResults.new(core, subsequent)
          @buffer                     = []
          @receive_envelope_scheduled = false
        end

        def on_envelope(envelope)
          @buffer.push envelope
          process_envelopes?
          NOT_PROCESSED
        end

        # Ensures that only one envelope processing is scheduled with #schedule_execution,
        # this allows other scheduled blocks to be executed before next envelope processing.
        # Simply put this ensures that Core is still responsive to internal calls (like add_child)
        # even though the Actor is flooded with messages.
        def process_envelopes?
          unless @buffer.empty? || @receive_envelope_scheduled
            @receive_envelope_scheduled = true
            receive_envelope
          end
        end

        def receive_envelope
          envelope = @buffer.shift
          return nil unless envelope
          pass envelope
        ensure
          @receive_envelope_scheduled = false
          schedule_execution { process_envelopes? }
        end

        def reject_messages
          @buffer.each { |envelope| reject_envelope envelope }
          @buffer.clear
          super
        end

        def schedule_execution(&block)
          core.schedule_execution &block
        end
      end

      class Await < Abstract
        def on_envelope(envelope)
          if envelope.message == :await
            true
          else
            pass envelope
          end
        end
      end

      class DoContext < Abstract
        def on_envelope(envelope)
          context.on_envelope envelope
        end
      end

      class ErrorOnUnknownMessage < Abstract
        def on_envelope(envelope)
          raise "unknown message #{envelope.message.inspect}"
        end
      end

    end
  end
end
