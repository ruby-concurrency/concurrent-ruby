module Concurrent
  module Actor

    # Reference is public interface of Actor instances. It is used for sending messages and can
    # be freely passed around the program. It also provides some basic information about the actor,
    # see {CoreDelegations}.
    class Reference
      include TypeCheck
      include CoreDelegations

      attr_reader :core
      private :core

      # @!visibility private
      def initialize(core)
        @core = Type! core, Core
      end

      # tells message to the actor
      # @param [Object] message
      # @return [Reference] self
      def tell(message)
        message message, nil
      end

      alias_method :<<, :tell

      # tells message to the actor
      # @param [Object] message
      # @param [Ivar] ivar to be fulfilled be message's processing result
      # @return [IVar] supplied ivar
      def ask(message, ivar = IVar.new)
        message message, ivar
      end

      # @note can lead to deadlocks, use only in tests or when you are sure it won't deadlock
      # tells message to the actor
      # @param [Object] message
      # @param [Ivar] ivar to be fulfilled be message's processing result
      # @return [Object] message's processing result
      # @raise [Exception] ivar.reason if ivar is #rejected?
      def ask!(message, ivar = IVar.new)
        ask(message, ivar).value!
      end

      # behaves as {#tell} when no ivar and as {#ask} when ivar
      def message(message, ivar = nil)
        core.on_envelope Envelope.new(message, ivar, Actor.current || Thread.current, self)
        return ivar || self
      end

      # @see Context#dead_letter_routing
      def dead_letter_routing
        core.dead_letter_routing
      end

      def to_s
        "#<#{self.class} #{path} (#{actor_class})>"
      end

      alias_method :inspect, :to_s

      def ==(other)
        Type? other, self.class and other.send(:core) == core
      end

      # to avoid confusion with Kernel.spawn
      undef_method :spawn
    end

  end
end
