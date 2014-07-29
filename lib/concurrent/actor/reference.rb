module Concurrent
  module Actor

    # Reference is public interface of Actor instances. It is used for sending messages and can
    # be freely passed around the program. It also provides some basic information about the actor,
    # see {PublicDelegations}.
    class Reference
      include TypeCheck
      include PublicDelegations

      attr_reader :core
      private :core

      # @!visibility private
      def initialize(core)
        @core = Type! core, Core
      end

      # tells message to the actor, returns immediately
      # @param [Object] message
      # @return [Reference] self
      def tell(message)
        message message, nil
      end

      alias_method :<<, :tell

      # @note it's a good practice to use tell whenever possible. Ask should be used only for
      # testing and when it returns very shortly. It can lead to deadlock if all threads in
      # global_task_pool will block on while asking. It's fine to use it form outside of actors and
      # global_task_pool.
      #
      # sends message to the actor and asks for the result of its processing, returns immediately
      # @param [Object] message
      # @param [Ivar] ivar to be fulfilled be message's processing result
      # @return [IVar] supplied ivar
      def ask(message, ivar = IVar.new)
        message message, ivar
      end

      # @note it's a good practice to use tell whenever possible. Ask should be used only for
      # testing and when it returns very shortly. It can lead to deadlock if all threads in
      # global_task_pool will block on while asking. It's fine to use it form outside of actors and
      # global_task_pool.
      #
      # sends message to the actor and asks for the result of its processing, blocks
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

      # @see AbstractContext#dead_letter_routing
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
