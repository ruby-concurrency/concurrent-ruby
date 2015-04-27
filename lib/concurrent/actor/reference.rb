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
      # global_io_executor will block on while asking. It's fine to use it form outside of actors and
      # global_io_executor.
      #
      # sends message to the actor and asks for the result of its processing, returns immediately
      # @param [Object] message
      # @param [Edge::Future] future to be fulfilled be message's processing result
      # @return [Edge::Future] supplied future
      def ask(message, future = Concurrent.future)
        message message, future
        # # @return [Future] a future
        # def ask(message)
        #   message message, ConcurrentNext.promise
      end

      # @note it's a good practice to use tell whenever possible. Ask should be used only for
      # testing and when it returns very shortly. It can lead to deadlock if all threads in
      # global_io_executor will block on while asking. It's fine to use it form outside of actors and
      # global_io_executor.
      #
      # sends message to the actor and asks for the result of its processing, blocks
      # @param [Object] message
      # @param [Edge::Future] future to be fulfilled be message's processing result
      # @return [Object] message's processing result
      # @raise [Exception] future.reason if future is #rejected?
      def ask!(message, future = Concurrent.future)
        ask(message, future).value!
        # # @param [Object] message
        # # @return [Object] message's processing result
        # # @raise [Exception] future.reason if future is #failed?
        # def ask!(message)
        #   ask(message).value!
      end

      # behaves as {#tell} when no future and as {#ask} when future
      def message(message, future = nil)
        core.on_envelope Envelope.new(message, future, Actor.current || Thread.current, self)
        return future || self
        # # behaves as {#tell} when no promise and as {#ask} when promise
        # def message(message, promise = nil)
        #   core.on_envelope Envelope.new(message, promise, Actor.current || Thread.current, self)
        #   return promise ? promise.future : self
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
