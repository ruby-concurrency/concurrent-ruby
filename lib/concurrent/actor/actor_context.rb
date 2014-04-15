require 'concurrent/actor/simple_actor_ref'

module Concurrent

  # Actor-based concurrency is all the rage in some circles. Originally described in
  # 1973, the actor model is a paradigm for creating asynchronous, concurrent objects
  # that is becoming increasingly popular. Much has changed since actors were first
  # written about four decades ago, which has led to a serious fragmentation within
  # the actor community. There is *no* universally accepted, strict definition of
  # "actor" and actor implementations differ widely between languages and libraries.
  # 
  # A good definition of "actor" is:
  # 
  #   An independent, concurrent, single-purpose, computational entity that communicates exclusively via message passing.
  #
  # The actor framework in this library is heavily influenced by the Akka toolkit,
  # with additional inspiration from Erlang and Scala. Unlike many of the abstractions
  # in this library, `ActorContext` takes an *object-oriented* approach to asynchronous
  # concurrency, rather than a *functional programming* approach.
  #
  # Creating an actor class is achieved by including the `ActorContext` module
  # within a standard Ruby class. One `ActorContext` is mixed in, however, everything
  # changes. Objects of the class can no longer be instanced with the `#new` method.
  # Instead, the various factor methods, such as `#spawn`, must be used. These factory
  # methods do not return direct references to the actor object. Instead they return
  # objects of one of the `ActorRef` subclasses. The `ActorRef` objects encapsulate
  # actor objects. This encapsulation is necessary to prevent synchronous method calls
  # froom being made against the actors. It also allows the messaging and lifecycle
  # behavior to be implemented within the `ActorRef` subclasses, allowing for better
  # separation of responsibility.
  #
  # @see Concurrent::ActorRef
  #
  # @see http://akka.io/
  # @see http://www.erlang.org/doc/getting_started/conc_prog.html
  # @see http://www.scala-lang.org/api/current/index.html#scala.actors.Actor
  #
  # @see http://doc.akka.io/docs/akka/snapshot/general/supervision.html#What_Restarting_Means What Restarting Means
  # @see http://doc.akka.io/docs/akka/snapshot/general/supervision.html#What_Lifecycle_Monitoring_Means What Lifecycle Monitoring Means
  module ActorContext

    # Callback method called by the `ActorRef` which encapsulates the actor instance.
    def on_start
    end

    # Callback method called by the `ActorRef` which encapsulates the actor instance.
    def on_reset
    end

    # Callback method called by the `ActorRef` which encapsulates the actor instance.
    def on_shutdown
    end

    # Callback method called by the `ActorRef` which encapsulates the actor instance.
    #
    # @param [Time] time the date/time at which the error occurred
    # @param [Array] message the message that caused the error
    # @param [Exception] exception the exception object that was raised
    def on_error(time, message, exception)
    end

    def self.included(base)

      class << base

        # Create a single, unregistered actor. The actor will run on its own, dedicated
        # thread. The thread will be started the first time a message is post to the actor.
        # Should the thread ever die it will be restarted the next time a message is post.
        #
        # @param [Hash] opts the options defining actor behavior
        # @option opts [Array] :args (`nil`) arguments to be passed to the actor constructor
        #
        # @return [SimpleActorRef] the `ActorRef` encapsulating the actor
        def spawn(opts = {})
          args = opts.fetch(:args, [])
          Concurrent::SimpleActorRef.new(self.new(*args), opts)
        end
      end
    end
  end
end
