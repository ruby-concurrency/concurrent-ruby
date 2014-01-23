require 'drb/drb'
require 'concurrent/actor_method_dispatcher'

module Concurrent

  class ActorServer
    extend Forwardable

    def_delegator :@dispatcher, :add

    def initialize(opts = {})
      @port = opts[:port] || 8787
      @host = opts[:host] || 'localhost'

      @dispatcher = ActorMethodDispatcher.new
      @drb_server = DRb.start_service(server_uri, @dispatcher)
    end

    def running?
      @drb_server.alive?
    end

    def stop
      @drb_server.stop_service if running?
    end

    private

    def server_uri
      "druby://#{@host}:#{@port}"
    end
  end
end
