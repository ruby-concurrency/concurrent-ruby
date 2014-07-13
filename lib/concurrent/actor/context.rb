module Concurrent
  module Actor

    # This module is used to define actors. It can be included in any class,
    # only requirement is to override {Context#on_message} method.
    # @example ping
    #  class Ping
    #    include Context
    #    def on_message(message)
    #      message
    #    end
    #  end
    #
    #  Ping.spawn(:ping1).ask(:m).value #=> :m

    module InstanceMethods
      include TypeCheck
      include InternalDelegations

      attr_reader :core

      # @abstract override to define Actor's behaviour
      # @param [Object] message
      # @return [Object] a result which will be used to set the IVar supplied to Reference#ask
      # @note self should not be returned (or sent to other actors), {#reference} should be used
      #   instead
      def on_message(message)
        raise NotImplementedError
      end

      # override to add custom code invocation on events like `:terminated`, `:resumed`, `anError`.
      def on_event(event)
      end

      # @api private
      def on_envelope(envelope)
        @envelope = envelope
        on_message envelope.message
      ensure
        @envelope = nil
      end

      # if you want to pass the message to next behaviour, usually {Behaviour::ErrorOnUnknownMessage}
      def pass
        core.behaviour!(Behaviour::ExecutesContext).pass envelope
      end

      # Defines an actor responsible for dead letters. Any rejected message send with
      # {Reference#tell} is sent there, a message with ivar is considered already monitored for
      # failures. Default behaviour is to use {Context#dead_letter_routing} of the parent,
      # so if no {Context#dead_letter_routing} method is overridden in parent-chain the message ends up in
      # `Actor.root.dead_letter_routing` agent which will log warning.
      # @return [Reference]
      def dead_letter_routing
        parent.dead_letter_routing
      end

      # @return [Array<Array(Behavior::Abstract, Array<Object>)>]
      def behaviour_definition
        raise NotImplementedError
      end

      # @return [Envelope] current envelope, accessible inside #on_message processing
      def envelope
        @envelope or raise 'envelope not set'
      end

      # override if different class for reference is needed
      # @return [CLass] descendant of {Reference}
      def default_reference_class
        Reference
      end

      private

      def initialize_core(core)
        @core = Type! core, Core
      end
    end

    module ClassMethods
      # behaves as {Concurrent::Actor.spawn} but :class is auto-inserted based on receiver
      def spawn(name_or_opts, *args, &block)
        Actor.spawn spawn_optionify(name_or_opts, *args), &block
      end

      # behaves as {Concurrent::Actor.spawn!} but :class is auto-inserted based on receiver
      def spawn!(name_or_opts, *args, &block)
        Actor.spawn! spawn_optionify(name_or_opts, *args), &block
      end

      private

      def spawn_optionify(name_or_opts, *args)
        if name_or_opts.is_a? Hash
          if name_or_opts.key?(:class) && name_or_opts[:class] != self
            raise ArgumentError,
                  ':class option is ignored when calling on context class, use Actor.spawn instead'
          end
          name_or_opts.merge class: self
        else
          { class: self, name: name_or_opts, args: args }
        end
      end
    end

    class Context
      include InstanceMethods
      extend ClassMethods

      # to avoid confusion with Kernel.spawn
      undef_method :spawn

      def behaviour_definition
        Behaviour.basic_behaviour
      end
    end

    class RestartingContext < Context
      def behaviour_definition
        Behaviour.restarting_behaviour
      end
    end
  end
end
