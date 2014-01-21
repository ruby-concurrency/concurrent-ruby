module Concurrent

  # ActorMethodDispatcher is responsible for the communication between the DRB server
  # and the Actors instance.

  class ActorMethodDispatcher

    def method_missing(meth, *args, &block)
      # select an available actor and call the method.
    end
  end
end
