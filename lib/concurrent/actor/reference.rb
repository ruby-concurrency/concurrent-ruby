module Concurrent
  module Actor

    # {Reference} is public interface of Actor instances. It is used for sending messages and can
    # be freely passed around the application. It also provides some basic information about the actor,
    # see {PublicDelegations}.
    #
    #     AdHoc.spawn('printer') { -> message { puts message } }
    #     # => #<Concurrent::Actor::Reference /printer (Concurrent::Actor::Utils::AdHoc)>
    #     #                                   ^path     ^context class
    class Reference
      include TypeCheck
      include PublicDelegations

      attr_reader :core
      private :core

      # @!visibility private
      def initialize(core)
        @core = Type! core, Core
      end

      # Sends the message asynchronously to the actor and immediately returns
      # `self` (the reference) allowing to chain message telling.
      # @param [Object] message
      # @return [Reference] self
      # @example
      #   printer = AdHoc.spawn('printer') { -> message { puts message } }
      #   printer.tell('ping').tell('pong')
      #   printer << 'ping' << 'pong'
      #   # => 'ping'\n'pong'\n'ping'\n'pong'\n
      def tell(message)
        message message, nil
      end

      alias_method :<<, :tell

      # Sends the message asynchronously to the actor and immediately returns {Concurrent::IVar}
      # which will become completed when message is processed.
      #
      # @note it's a good practice to use {#tell} whenever possible. Results can be send back with other messages.
      #   Ask should be used only for testing and when it returns very shortly. It can lead to deadlock if all threads in
      #   global_task_pool will block on while asking. It's fine to use it form outside of actors and
      #   global_task_pool.
      # @param [Object] message
      # @param [Ivar] ivar to be fulfilled be message's processing result
      # @return [IVar] supplied ivar
      # @example
      #   adder = AdHoc.spawn('adder') { -> message { message + 1 } }
      #   adder.ask(1).value # => 2
      #   adder.ask(nil).wait.reason # => #<NoMethodError: undefined method `+' for nil:NilClass>
      def ask(message, ivar = IVar.new)
        message message, ivar
      end

      # Sends the message synchronously and blocks until the message
      # is processed. Raises on error.
      #
      # @note it's a good practice to use {#tell} whenever possible. Results can be send back with other messages.
      #   Ask should be used only for testing and when it returns very shortly. It can lead to deadlock if all threads in
      #   global_task_pool will block on while asking. It's fine to use it form outside of actors and
      #   global_task_pool.
      # @param [Object] message
      # @param [Ivar] ivar to be fulfilled be message's processing result
      # @return [Object] message's processing result
      # @raise [Exception] ivar.reason if ivar is #rejected?
      # @example
      #   adder = AdHoc.spawn('adder') { -> message { message + 1 } }
      #   adder.ask!(1) # => 2
      def ask!(message, ivar = IVar.new)
        ask(message, ivar).value!
      end

      def map(messages)
        messages.map { |m| self.ask(m) }
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
        "#<#{self.class}:0x#{'%x' % (object_id << 1)} #{path} (#{actor_class})>"
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
