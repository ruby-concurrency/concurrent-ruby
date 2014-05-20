module Concurrent
  module Actress

    # module used to define actor behaviours
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
      def on_message(message)
        raise NotImplementedError
      end

      def logger
        core.logger
      end

      # @api private
      def on_envelope(envelope)
        @envelope = envelope
        on_message envelope.message
      ensure
        @envelope = nil
      end

      # @see Actress.spawn
      def spawn(actress_class, name, *args, &block)
        Actress.spawn(actress_class, name, *args, &block)
      end

      # @see Core#children
      def children
        core.children
      end

      # @see Core#terminate!
      def terminate!
        core.terminate!
      end

      private

      # @api private
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
        # behaves as {Actress.spawn} but class_name is omitted
        def spawn(name, *args, &block)
          Actress.spawn self, name, *args, &block
        end
      end
    end
  end
end
