module Concurrent

  module Postable

    Package = Struct.new(:message, :handler, :notifier)

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
