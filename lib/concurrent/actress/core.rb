module Concurrent
  module Actress

    # Core of the actor
    # @api private
    class Core
      include TypeCheck

      attr_reader :reference, :name, :path, :logger, :parent_core
      private :parent_core

      # @param [Reference, nil] parent of an actor spawning this one
      # @param [String] name
      # @param [Context] actress_class a class to be instantiated defining Actor's behaviour
      # @param args arguments for actress_class instantiation
      # @param block for actress_class instantiation
      def initialize(parent, name, actress_class, *args, &block)
        @mailbox         = Array.new
        @one_by_one      = OneByOne.new
        @executor        = Concurrent.configuration.global_task_pool # TODO make configurable
        @parent_core     = (Type! parent, Reference, NilClass) && parent.send(:core)
        @name            = (Type! name, String, Symbol).to_s
        @children        = []
        @path            = @parent_core ? File.join(@parent_core.path, @name) : @name
        @logger          = Logger.new($stderr) # TODO add proper logging
        @logger.progname = @path
        @reference       = Reference.new self
        # noinspection RubyArgCount
        @terminated      = Event.new

        parent_core.add_child reference if parent_core

        @actress_class = Child! actress_class, Context
        schedule_execution do
          begin
            @actress = actress_class.new *args, &block
            @actress.send :initialize_core, self
          rescue => ex
            puts "#{ex} (#{ex.class})\n#{ex.backtrace.join("\n")}"
            terminate! # TODO test that this is ok
          end
        end
      end

      # @return [Reference] of parent actor
      def parent
        @parent_core.reference
      end

      # @return [Array<Reference>] of children actors
      def children
        guard!
        @children.dup
      end

      # @api private
      def add_child(child)
        guard!
        @children << (Type! child, Reference)
        self
      end

      # @api private
      def remove_child(child)
        schedule_execution do
          Type! child, Reference
          @children.delete child
        end
        self
      end

      # is executed by Reference scheduling processing of new messages
      # can be called from other alternative Reference implementations
      # @param [Envelope] envelope
      def on_envelope(envelope)
        schedule_execution do
          if terminated?
            reject_envelope envelope
          else
            @mailbox.push envelope
          end
          process_envelopes?
        end
        self
      end

      # @note Actor rejects envelopes when terminated.
      # @return [true, false] if actor is terminated
      def terminated?
        @terminated.set?
      end

      # Terminates the actor, any Envelope received after termination is rejected
      def terminate!
        guard!
        @terminated.set
        parent_core.remove_child reference if parent_core
        @mailbox.each do |envelope|
          reject_envelope envelope
          logger.debug "rejected #{envelope.message} from #{envelope.sender_path}"
        end
        @mailbox.clear
        # TODO terminate all children
        self
      end

      # @api private
      # ensures that we are inside of the executor
      def guard!
        unless Actress.current == reference
          raise "can be called only inside actor #{reference} but was #{Actress.current}"
        end
      end

      private

      # Ensures that only one envelope processing is scheduled with #schedule_execution,
      # this allows other scheduled blocks to be executed before next envelope processing.
      # Simply put this ensures that Core is still responsive to internal calls (like add_child)
      # even though the Actor is flooded with messages.
      def process_envelopes?
        unless @mailbox.empty? || @receive_envelope_scheduled
          @receive_envelope_scheduled = true
          schedule_execution { receive_envelope }
        end
      end

      # Processes single envelope, calls #process_envelopes? at the end to ensure next envelope
      # scheduling.
      def receive_envelope
        envelope = @mailbox.shift

        if terminated?
          reject_envelope envelope
          puts "this should not happen"
        end

        logger.debug "received #{envelope.message} from #{envelope.sender_path}"

        result = @actress.on_envelope envelope
        envelope.ivar.set result unless envelope.ivar.nil?
      rescue => error
        logger.error error
        envelope.ivar.fail error unless envelope.ivar.nil?
      ensure
        @receive_envelope_scheduled = false
        process_envelopes?
      end

      # Schedules blocks to be executed on executor sequentially,
      # sets Actress.current
      def schedule_execution
        @one_by_one.post(@executor) do
          begin
            Thread.current[:__current_actress__] = reference
            yield
          rescue => e
            logger.error e
          ensure
            Thread.current[:__current_actress__] = nil
          end
        end
        self
      end

      def reject_envelope(envelope)
        envelope.reject! ActressTerminated.new(reference)
      end
    end
  end
end
