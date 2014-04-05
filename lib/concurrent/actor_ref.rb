require 'concurrent/utilities'

module Concurrent

  module ActorRef

    def running?
      true
    end

    def shutdown?
      false
    end

    def post(*msg, &block)
      raise NotImplementedError
    end

    def post!(*msg)
      raise NotImplementedError
    end

    def <<(message)
      post(*message)
      self
    end
  end
end
