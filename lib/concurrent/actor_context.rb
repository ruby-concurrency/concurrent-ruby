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

      class << base
        protected :new

        def spawn(opts = {})
          args = opts.fetch(:args, [])
          Concurrent::SimpleActorRef.new(self.new(*args))
        end
      end
    end
  end
end
