module Concurrent

  # ActorMethodDispatcher is responsible for the communication between the DRB server
  # and the Actors instance.

  class ActorMethodDispatcher

    def initialize
      @receivers = {}
    end

    def add(name, instance)
      @receivers[name] = instance
    end

    def connected?
      true
    end
  end
end
