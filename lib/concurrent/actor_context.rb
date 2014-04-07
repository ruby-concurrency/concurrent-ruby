require 'concurrent/simple_actor_ref'

module Concurrent

  module ActorContext

    def on_start
    end

    def on_reset
    end

    def on_shutdown
    end

    def on_error(time, message, exception)
    end

    def self.included(base)

      class << base
        protected :new

        def spawn(opts = {})
          args = opts.fetch(:args, [])
          Concurrent::SimpleActorRef.new(self.new(*args), opts)
        end
      end
    end
  end
end
