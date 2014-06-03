module Concurrent
  module Actress

    require 'set'

    # Core of the actor
    # @api private
    # @note devel: core should not block on anything, e.g. it cannot wait on children to terminate
    #   that would eat up all threads in task pool and deadlock
    class Core
      include TypeCheck
      include Concurrent::Logging

      attr_reader :reference, :name, :path, :executor, :terminated, :actor_class

      # @option opts [String] name
      # @option opts [Reference, nil] parent of an actor spawning this one
      # @option opts [Context] actress_class a class to be instantiated defining Actor's behaviour
      # @option opts [Array<Object>] args arguments for actress_class instantiation
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

        parent       = opts[:parent]
        @parent_core = (Type! parent, Reference, NilClass) && parent.send(:core)
        if @parent_core.nil? && @name != '/'
          raise 'only root has no parent'
        end

        @path   = @parent_core ? File.join(@parent_core.path, @name) : @name
        @logger = opts[:logger]

        @parent_core.add_child reference if @parent_core

        @actor_class = actress_class = Child! opts.fetch(:class), Context
        args         = opts.fetch(:args, [])
        initialized  = Type! opts[:initialized], IVar, NilClass

        schedule_execution do
          begin
            @actress = actress_class.new *args, &block
            @actress.send :initialize_core, self
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
          log FATAL, "this should not be happening #{caller[0]}"
        end

        log DEBUG, "received #{envelope.message} from #{envelope.sender_path}"

        result = @actress.on_envelope envelope
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
            Thread.current[:__current_actress__] = reference
            yield
          rescue => e
            log FATAL, e
          ensure
            Thread.current[:__current_actress__] = nil
          end
        end

        nil
      end

      def reject_envelope(envelope)
        envelope.reject! ActressTerminated.new(reference)
      end

      def log(level, message = nil, &block)
        super level, @path, message, &block
      end
    end
  end
end
