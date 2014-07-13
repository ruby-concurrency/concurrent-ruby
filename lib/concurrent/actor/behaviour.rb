module Concurrent
  module Actor

    # TODO split this into files
    # TODO document dependencies
    module Behaviour
      MESSAGE_PROCESSED = Object.new

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
            MESSAGE_PROCESSED
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
          @terminated.set
          broadcast(:terminated)
          parent << :remove_child if parent
          nil
        end
      end

      class TerminateChildren < Abstract
        def on_event(event)
          children.each { |ch| ch << :terminate! } if event == :terminated
          super event
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
            link envelope.sender
          when :unlink
            unlink envelope.sender
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

      class Supervising < Abstract
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

      # pause on error ask its parent
      # handling
      # :continue
      # :reset will only rebuild context
      # :restart drops messaged and as :reset
      # TODO callbacks

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
        attr_reader :error_strategy

        def initialize(core, subsequent, error_strategy)
          super core, subsequent
          @error_strategy = Match! error_strategy, :just_log, :terminate, :pause
        end

        def on_envelope(envelope)
          result = pass envelope
          if result != MESSAGE_PROCESSED && !envelope.ivar.nil?
            envelope.ivar.set result
          end
          nil
        rescue => error
          log Logging::ERROR, error
          case error_strategy
          when :terminate
            terminate!
          when :pause
            behaviour!(Pausing).pause!(error)
          else
            raise
          end
          envelope.ivar.fail error unless envelope.ivar.nil?
        end
      end

      class Buffer < Abstract
        def initialize(core, subsequent)
          super core, subsequent
          @buffer                     = []
          @receive_envelope_scheduled = false
        end

        def on_envelope(envelope)
          @buffer.push envelope
          process_envelopes?
          MESSAGE_PROCESSED
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
          core.schedule_execution { process_envelopes? }
        end

        def on_event(event)
          if event == :terminated
            @buffer.each { |envelope| reject_envelope envelope }
            @buffer.clear
          end
          super event
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
          raise UnknownMessage, envelope
        end
      end

      def self.basic_behaviour
        [*base,
         *user_messages(:terminate)]
      end

      def self.restarting_behaviour
        [*base,
         *supervising,
         *user_messages(:pause)]
      end

      def self.base
        [[SetResults, [:terminate]],
         [RemoveChild, []],
         [Termination, []],
         [TerminateChildren, []],
         [Linking, []]]
      end

      def self.supervising
        [[Supervising, []],
         [Pausing, []]]
      end

      def self.user_messages(on_error)
        [[Buffer, []],
         [SetResults, [on_error]],
         [Await, []],
         [DoContext, []],
         [ErrorOnUnknownMessage, []]]
      end
    end
  end
end
