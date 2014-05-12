require 'algebrick'
require 'atomic'
require 'logger'

module Concurrent
  module Actress
    Error = Class.new(StandardError)

    class ActressTerminated < Error
      include Algebrick::TypeCheck

      def initialize(reference)
        Type! reference, Reference
        super reference.path
      end
    end

    def self.current
      Thread.current[:__current_actress__]
    end

    module CoreDelegations
      def path
        core.path
      end

      def parent
        core.parent
      end

      def terminated?
        core.terminated?
      end

      def reference
        core.reference
      end

      alias_method :ref, :reference
    end

    class Reference
      include Algebrick::TypeCheck
      include Algebrick::Types
      include CoreDelegations

      attr_reader :core
      private :core

      def initialize(core)
        @core = Type! core, Core
      end


      def tell(message)
        message message, nil
      end

      alias_method :<<, :tell

      def ask(message, ivar = IVar.new)
        message message, ivar
      end

      def message(message, ivar = nil)
        core.on_envelope Envelope[message,
                                  ivar ? Some[IVar][ivar] : None,
                                  Actress.current ? Some[Reference][Actress.current] : None]
        return ivar || self
      end

      def to_s
        "#<#{self.class} #{path}>"
      end

      alias_method :inspect, :to_s

      def ==(other)
        Type? other, self.class and other.send(:core) == core
      end
    end

    include Algebrick::Types

    Envelope = Algebrick.type do
      fields! message: Object,
              ivar:    Maybe[IVar],
              sender:  Maybe[Reference]
    end

    module Envelope
      def sender_path
        sender.maybe { |reference| reference.path } || 'outside-actress'
      end

      def reject!(error)
        ivar.maybe { |v| v.fail error }
      end
    end

    class Core
      include Algebrick::TypeCheck

      attr_reader :reference, :name, :path, :logger, :parent_core
      private :parent_core

      def initialize(parent, name, actress_class, *args, &block)
        @mailbox         = Array.new
        @one_by_one      = OneByOne.new
        @executor        = Concurrent.configuration.global_task_pool # TODO configurable
        @parent_core     = (Type! parent, Reference, NilClass) && parent.send(:core)
        @name            = (Type! name, String, Symbol).to_s
        @children        = Atomic.new []
        @path            = @parent_core ? File.join(@parent_core.path, @name) : @name
        @logger          = Logger.new($stderr) # TODO add proper logging
        @logger.progname = @path
        @reference       = Reference.new self
        # noinspection RubyArgCount
        @terminated      = Event.new
        @mutex           = Mutex.new

        @actress_class = Child! actress_class, Abstract
        schedule_execution do
          parent_core.add_child reference if parent_core
          @actress = actress_class.new self, *args, &block # FIXME it may fail
        end
      end

      def parent
        @parent_core.reference
      end

      def children
        @children.get
      end

      def add_child(child)
        Type! child, Reference
        @children.update { |o| [*o, child] }
      end

      def remove_child(child)
        Type! child, Reference
        @children.update { |o| o - [child] }
      end

      def on_envelope(envelope)
        schedule_execution { execute_on_envelope envelope }
      end

      def terminated?
        @terminated.set?
      end

      def terminate!
        guard!
        @terminated.set
        parent_core.remove_child reference if parent_core
      end

      def guard!
        raise 'can be called only inside this actor' unless Actress.current == reference
      end

      private

      def process?
        unless @mailbox.empty? || @receive_envelope_scheduled
          @receive_envelope_scheduled = true
          schedule_execution { receive_envelope }
        end
      end

      def receive_envelope
        envelope = @mailbox.shift

        if terminated?
          # FIXME make sure that it cannot be GCed before all messages are rejected after termination
          reject_envelope envelope
          logger.debug "rejected #{envelope.message} from #{envelope.sender_path}"
          return
        end
        logger.debug "received #{envelope.message} from #{envelope.sender_path}"

        result = @actress.on_envelope envelope
        envelope.ivar.maybe { |iv| iv.set result }
      rescue => error
        logger.error error
        envelope.ivar.maybe { |iv| iv.fail error }
      ensure
        @receive_envelope_scheduled = false
        process?
      end

      def schedule_execution
        @one_by_one.post(@executor) do
          begin
            # TODO enable this mutex only on JRuby
            @mutex.lock # only for JRuby
            Thread.current[:__current_actress__] = reference
            yield
          rescue => e
            puts e
          ensure
            Thread.current[:__current_actress__] = nil
            @mutex.unlock # only for JRuby
          end
        end
      end

      def execute_on_envelope(envelope)
        if terminated?
          reject_envelope envelope
        else
          @mailbox.push envelope
        end
        process?
      end

      def create_and_set_actor(actress_class, block, *args)
        parent_core.add_child reference if parent_core
        @actress = actress_class.new self, *args, &block # FIXME may fail
      end

      def reject_envelope(envelope)
        envelope.reject! ActressTerminated.new(reference)
      end
    end

    class Abstract
      include Algebrick::TypeCheck
      extend Algebrick::TypeCheck
      include Algebrick::Matching
      include CoreDelegations

      attr_reader :core

      def self.new(core, *args, &block)
        allocate.tap do |actress|
          actress.__send__ :pre_initialize, core
          actress.__send__ :initialize, *args, &block
        end
      end

      def on_message(message)
        raise NotImplementedError
      end

      def logger
        core.logger
      end

      def on_envelope(envelope)
        @envelope = envelope
        on_message envelope.message
      ensure
        @envelope = nil
      end

      def spawn(actress_class, name, *args, &block)
        Actress.spawn(actress_class, name, *args, &block)
      end

      def children
        core.children
      end

      def terminate!
        core.terminate!
      end

      private

      def pre_initialize(core)
        @core = Type! core, Core
      end

      def envelope
        @envelope or raise 'envelope not set'
      end
    end

    class Root < Abstract
      def on_message(message)
        # ignore
      end
    end

    ROOT = Core.new(nil, '/', Root).reference

    def self.spawn(actress_class, name, *args, &block)
      Core.new(Actress.current || ROOT, name, actress_class, *args, &block).reference
    end
  end
end
