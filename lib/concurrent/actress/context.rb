module Concurrent
  module Actress

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
    module Context
      include TypeCheck
      include CoreDelegations

      attr_reader :core

      # @abstract override to define Actor's behaviour
      # @param [Object] message
      # @return [Object] a result which will be used to set the IVar supplied to Reference#ask
      # @note self should not be returned (or sent to other actors), {#reference} should be used
      #   instead
      def on_message(message)
        raise NotImplementedError
      end

      # @api private
      def on_envelope(envelope)
        @envelope = envelope
        on_message envelope.message
      ensure
        @envelope = nil
      end

      # @see Actress.spawn
      def spawn(*args, &block)
        Actress.spawn(*args, &block)
      end

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

      # Defines an actor responsible for dead letters. Any rejected message send with
      # {Reference#tell} is sent there, a message with ivar is considered already monitored for
      # failures. Default behaviour is to use {Context#dead_letter_routing} of the parent,
      # so if no {Context#dead_letter_routing} method is overridden in parent-chain the message ends up in
      # `Actress.root.dead_letter_routing` agent which will log warning.
      # @return [Reference]
      def dead_letter_routing
        parent.dead_letter_routing
      end

      private

      def initialize_core(core)
        @core = Type! core, Core
      end

      # @return [Envelope] current envelope, accessible inside #on_message processing
      def envelope
        @envelope or raise 'envelope not set'
      end

      def self.included(base)
        base.extend ClassMethods
        super base
      end

      module ClassMethods
        # behaves as {Concurrent::Actress.spawn} but class_name is auto-inserted based on receiver
        def spawn(name_or_opts, *args, &block)
          Actress.spawn spawn_optionify(name_or_opts, *args), &block
        end

        # behaves as {Concurrent::Actress.spawn!} but class_name is auto-inserted based on receiver
        def spawn!(name_or_opts, *args, &block)
          Actress.spawn! spawn_optionify(name_or_opts, *args), &block
        end

        private

        def spawn_optionify(name_or_opts, *args)
          if name_or_opts.is_a? Hash
            name_or_opts.merge class: self
          else
            { class: self, name: name_or_opts, args: args }
          end
        end
      end
    end
  end
end
