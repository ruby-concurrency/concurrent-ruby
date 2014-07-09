module Concurrent
  module Actor

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
      attr_reader :reference, :name, :path, :executor, :context_class, :context

      # @option opts [String] name
      # @option opts [Reference, nil] parent of an actor spawning this one
      # @option opts [Class] reference a custom descendant of {Reference} to use
      # @option opts [Context] actor_class a class to be instantiated defining Actor's behaviour
      # @option opts [Array<Object>] args arguments for actor_class instantiation
      # @option opts [Executor] executor, default is `Concurrent.configuration.global_task_pool`
      # @option opts [IVar, nil] initialized, if present it'll be set or failed after {Context} initialization
      # @option opts [Proc, nil] logger a proc accepting (level, progname, message = nil, &block) params,
      #   can be used to hook actor instance to any logging system
      # @param [Proc] block for class instantiation
      def initialize(opts = {}, &block)
        # @mutex = Mutex.new
        # @mutex.lock
        # FIXME make initialization safe!

        @mailbox              = Array.new
        @serialized_execution = SerializedExecution.new
        @executor             = Type! opts.fetch(:executor, Concurrent.configuration.global_task_pool), Executor
        @children             = Set.new
        @context_class        = Child! opts.fetch(:class), Context
        @context              = @context_class.allocate
        @reference            = (Child! opts[:reference_class] || @context.default_reference_class, Reference).new self
        @name = (Type! opts.fetch(:name), String, Symbol).to_s

        parent       = opts[:parent]
        @parent_core = (Type! parent, Reference, NilClass) && parent.send(:core)
        if @parent_core.nil? && @name != '/'
          raise 'only root has no parent'
        end

        @path   = @parent_core ? File.join(@parent_core.path, @name) : @name
        @logger = opts[:logger]

        @parent_core.add_child reference if @parent_core

        @behaviours      = {}
        @first_behaviour = @context.behaviour_classes.reverse.
            reduce(nil) { |last, behaviour| @behaviours[behaviour] = behaviour.new(self, last) }

        args        = opts.fetch(:args, [])
        initialized = Type! opts[:initialized], IVar, NilClass

        schedule_execution do
          begin
            @context.tap do |a|
              a.send :initialize_core, self
              a.send :initialize, *args, &block
            end

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
        @context.dead_letter_routing
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
        guard!
        Type! child, Reference
        @children.delete child
        nil
      end

      # is executed by Reference scheduling processing of new messages
      # can be called from other alternative Reference implementations
      # @param [Envelope] envelope
      def on_envelope(envelope)
        schedule_execution do
          log DEBUG, "received #{envelope.message.inspect} from #{envelope.sender}"
          @first_behaviour.on_envelope envelope
        end
        nil
      end

      # @note Actor rejects envelopes when terminated.
      # @return [true, false] if actor is terminated
      def terminated?
        behaviour!(Behaviour::Termination).terminated?
      end

      def terminate!
        behaviour!(Behaviour::Termination).terminate!
      end

      def terminated
        behaviour!(Behaviour::Termination).terminated
      end

      # @api private
      # ensures that we are inside of the executor
      def guard!
        unless Actor.current == reference
          raise "can be called only inside actor #{reference} but was #{Actor.current}"
        end
      end

      # @api private
      def log(level, message = nil, &block)
        super level, @path, message, &block
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

      def reject_messages
        @first_behaviour.reject_messages
      end

      def behaviour(klass)
        @behaviours[klass]
      end

      def behaviour!(klass)
        @behaviours.fetch klass
      end
    end
  end
end
