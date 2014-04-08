require 'concurrent/copy_on_notify_observer_set'

module Concurrent

  # Base class for classes that encapsulate +ActorContext+ objects.
  #
  # @see Concurrent::ActorContext
  module ActorRef

    #NOTE: Required API methods
    #      Must be implemented in all subclasses
    #def post(*msg, &block)
    #def post!(*msg)
    #def running?
    #def shutdown?
    #def shutdown
    #def join(timeout = nil)

    # @!method post(*msg, &block)
    #
    #   Send a message and return a future which will eventually be updated
    #   with the result of the operation. An optional callback block can be
    #   given which will be called once the operation is complete. Although
    #   it is possible to use a callback block and also interrogate the
    #   returned future it is a good practice to do one or the other.
    #
    #   @param [Array] msg One or more elements of the message
    #
    #   @yield a callback operation to be performed when the operation is complete.
    #   @yieldparam [Time] time the date/time at which the error occurred
    #   @yieldparam [Object] result the result of message processing or +nil+ on error
    #   @yieldparam [Exception] exception the exception object that was raised or +nil+ on success
    #
    #   @return [IVar] a future that will eventually contain the result of message processing

    # @!method post!(timeout, *msg)
    #   Send a message synchronously and block awaiting the response.
    #
    #   @param [Integer] timeout the maximum number of seconds to block waiting
    #     for a response
    #   @param [Array] msg One or more elements of the message
    #
    #   @return [Object] the result of successful message processing
    #
    #   @raise [Concurrent::TimeoutError] if a timeout occurs
    #   @raise [Exception] an exception which occurred during message processing

    # @!method running?()
    #   Is the actor running and processing messages?
    #   @return [Boolean] +true+ if running else +false+

    # @!method shutdown?()
    #   Is the actor shutdown and no longer processing messages?
    #   @return [Boolean] +true+ if shutdown else +false+

    # @!method shutdown()
    #   Shutdown the actor, gracefully exit all threads, and stop processing messages.
    #   @return [Boolean] +true+ if shutdown is successful else +false+

    # @!method join(limit = nil)
    #   Suspend the current thread until the actor has been shutdown
    #   @param [Integer] limit the maximum number of seconds to block waiting for the
    #     actor to shutdown. Block indefinitely when +nil+ or not given
    #   @return [Boolean] +true+ if the actor shutdown before the limit expired else +false+
    #   @see http://www.ruby-doc.org/core-2.1.1/Thread.html#method-i-join

    def <<(message)
      post(*message)
      self
    end

    def add_observer(*args)
      @observers.add_observer(*args)
    end

    def delete_observer(*args)
      @observers.delete_observer(*args)
    end

    def delete_observers
      @observers.delete_observers
    end

    protected

    def observers
      @observers ||= CopyOnNotifyObserverSet.new
    end
  end
end
