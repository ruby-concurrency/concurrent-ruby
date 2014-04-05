require 'concurrent/simple_actor_ref'

module Concurrent

  module ActorContext

    def on_start
    end

    def on_restart
    end

    def on_shutdown
    end

    def self.included(base)

      def base.spawn
        Concurrent::SimpleActorRef.new(self.new)
      end
    end
  end
end
