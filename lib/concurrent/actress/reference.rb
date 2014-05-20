module Concurrent
  module Actress

    # Reference serves as public interface to send messages to Actors and can freely passed around
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

      # @note can lead to deadlocks
      # tells message to the actor
      # @param [Object] message
      # @param [Ivar] ivar to be fulfilled be message's processing result
      # @return [Object] message's processing result
      # @raise [Exception] ivar.reason if ivar is #rejected?
      def ask!(message, ivar = IVar.new)
        ask(message, ivar).value!
      end

      # behaves as #tell when no ivar and as #ask when ivar
      def message(message, ivar = nil)
        core.on_envelope Envelope.new(message, ivar, Actress.current || Thread.current)
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

  end
end
