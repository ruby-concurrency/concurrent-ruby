module Concurrent
  module Actress

    require 'set'

    # Core of the actor
    # @note Whole class should be considered private. An user should use {Context}s and {Reference}s only.
    # @note devel: core should not block on anything, e.g. it cannot wait on children to terminate
    #   that would eat up all threads in task pool and deadlock
    class Core
      include TypeCheck
      include Concurrent::Logging

      # @!attribute [r] reference
      #   @return [Reference] reference to this actor which can be safely passed around
      # @!attribute [r] name
      #   @return [String] the name of this instance, it should be uniq (not enforced right now)
      # @!attribute [r] path
      #   @return [String] a path of this actor. It is used for easier orientation and logging.
      #     Path is constructed recursively with: `parent.path + self.name` up to a {Actress.root},
      #     e.g. `/an_actor/its_child`.
      #     (It will also probably form a supervision path (failures will be reported up to parents)
      #     in future versions.)
      # @!attribute [r] executor
      #   @return [Executor] which is used to process messages
      # @!attribute [r] terminated
      #   @return [Event] event which will become set when actor is terminated.
      # @!attribute [r] actor_class
      #   @return [Context] a class including {Context} representing Actor's behaviour
      attr_reader :reference, :name, :path, :executor, :terminated, :actor_class

      # @option opts [String] name
      # @option opts [Reference, nil] parent of an actor spawning this one
      # @option opts [Context] actor_class a class to be instantiated defining Actor's behaviour
      # @option opts [Array<Object>] args arguments for actor_class instantiation
      # @option opts [Executor] executor, default is `Concurrent.configuration.global_task_pool`
      # @option opts [IVar, nil] initialized, if present it'll be set or failed after {Context} initialization
      # @option opts [Proc, nil] logger a proc accepting (level, progname, message = nil, &block) params,
      #   can be used to hook actor instance to any logging system
      # @param [Proc] block for class instantiation
      def initialize(opts = {}, &block)
        @mailbox              = Array.new
        @serialized_execution = SerializedExecution.new
        # noinspection RubyArgCount
        @terminated           = Event.new
        @executor             = Type! opts.fetch(:executor, Concurrent.configuration.global_task_pool), Executor
        @children             = Set.new
        @reference            = Reference.new self
        @name                 = (Type! opts.fetch(:name), String, Symbol).to_s
        @actor                = Concurrent::Atomic.new

        parent       = opts[:parent]
        @parent_core = (Type! parent, Reference, NilClass) && parent.send(:core)
        if @parent_core.nil? && @name != '/'
          raise 'only root has no parent'
        end

        @path   = @parent_core ? File.join(@parent_core.path, @name) : @name
        @logger = opts[:logger]

        @parent_core.add_child reference if @parent_core

        @actor_class = actor_class = Child! opts.fetch(:class), Context
        args         = opts.fetch(:args, [])
        initialized  = Type! opts[:initialized], IVar, NilClass

        schedule_execution do
          begin
            @actor.value = actor_class.new(*args, &block).
                tap { |a| a.send :initialize_core, self }
            initialized.set true if initialized
          rescue => ex
            log ERROR, ex
            terminate!
            initialized.fail ex if initialized
          end
        end
      end

      # @return [Reference, nil] of parent actor
      def parent
        @parent_core && @parent_core.reference
      end

      # @see Context#dead_letter_routing
      def dead_letter_routing
        @actor.value.dead_letter_routing
      end

      # @return [Array<Reference>] of children actors
      def children
        guard!
        @children.to_a
      end

      # @api private
      def add_child(child)
        guard!
        Type! child, Reference
        @children.add child
        nil
      end

      # @api private
      def remove_child(child)
        schedule_execution do
          Type! child, Reference
          @children.delete child
        end
        nil
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
        nil
      end

      # @note Actor rejects envelopes when terminated.
      # @return [true, false] if actor is terminated
      def terminated?
        @terminated.set?
      end

      # Terminates the actor. Any Envelope received after termination is rejected.
      # Terminates all its children, does not wait until they are terminated.
      def terminate!
        guard!
        return nil if terminated?

        @children.each do |ch|
          ch.send(:core).tap { |core| core.send(:schedule_execution) { core.terminate! } }
        end

        @terminated.set

        @parent_core.remove_child reference if @parent_core
        @mailbox.each do |envelope|
          reject_envelope envelope
          log DEBUG, "rejected #{envelope.message} from #{envelope.sender_path}"
        end
        @mailbox.clear

        nil
      end

      # @api private
      # ensures that we are inside of the executor
      def guard!
        unless Actress.current == reference
          raise "can be called only inside actor #{reference} but was #{Actress.current}"
        end
      end

      # @api private
      def log(level, message = nil, &block)
        super level, @path, message, &block
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

      # @return [Context]
      def actor
        @actor.value
      end

      # Processes single envelope, calls #process_envelopes? at the end to ensure next envelope
      # scheduling.
      def receive_envelope
        envelope = @mailbox.shift

        if terminated?
          reject_envelope envelope
          log FATAL, "this should not be happening #{caller[0]}"
        end

        log DEBUG, "received #{envelope.message} from #{envelope.sender_path}"

        result = actor.on_envelope envelope
        envelope.ivar.set result unless envelope.ivar.nil?

        nil
      rescue => error
        log ERROR, error
        terminate!
        envelope.ivar.fail error unless envelope.ivar.nil?
      ensure
        @receive_envelope_scheduled = false
        process_envelopes?
      end

      # Schedules blocks to be executed on executor sequentially,
      # sets Actress.current
      def schedule_execution
        @serialized_execution.post(@executor) do
          begin
            Thread.current[:__current_actor__] = reference
            yield
          rescue => e
            log FATAL, e
          ensure
            Thread.current[:__current_actor__] = nil
          end
        end

        nil
      end

      def reject_envelope(envelope)
        envelope.reject! ActressTerminated.new(reference)
        dead_letter_routing << envelope unless envelope.ivar
      end
    end
  end
end
