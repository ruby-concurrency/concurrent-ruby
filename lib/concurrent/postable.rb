module Concurrent

  module Postable

    # @!visibility private
    Package = Struct.new(:message, :handler, :notifier) # :nodoc:

    # Sends a message to and returns. It's a fire-and-forget interaction.
    #
    # @example
    #   class EchoActor < Concurrent::Actor
    #     def act(*message)
    #       p message
    #     end
    #   end
    #   
    #   echo = EchoActor.new
    #   echo.run!
    #   
    #   echo.post("Don't panic") #=> true
    #   #=> ["Don't panic"]
    #   
    #   echo.post(1, 2, 3, 4, 5) #=> true
    #   #=> [1, 2, 3, 4, 5]
    #   
    #   echo << "There's a frood who really knows where his towel is." #=> #<EchoActor:0x007fc8012b8448...
    #   #=> ["There's a frood who really knows where his towel is."]
    def post(*message)
      return false unless ready?
      queue.push(Package.new(message))
      return queue.length
    end

    def <<(message)
      post(*message)
      return self
    end

    def post?(*message)
      return nil unless ready?
      contract = Contract.new
      queue.push(Package.new(message, contract))
      return contract
    end

    def post!(seconds, *message)
      raise Concurrent::Runnable::LifecycleError unless ready?
      raise Concurrent::TimeoutError if seconds.to_f <= 0.0
      event = Event.new
      cback = Queue.new
      queue.push(Package.new(message, cback, event))
      if event.wait(seconds)
        result = cback.pop
        if result.is_a?(Exception)
          raise result
        else
          return result
        end
      else
        event.set # attempt to cancel
        raise Concurrent::TimeoutError
      end
    end

    def forward(receiver, *message)
      return false unless ready?
      queue.push(Package.new(message, receiver))
      return queue.length
    end

    def ready?
      if self.respond_to?(:running?) && ! running?
        return false
      else
        return true
      end
    end

    private

    # @private
    def queue # :nodoc:
      @queue ||= Queue.new
    end
  end
end
