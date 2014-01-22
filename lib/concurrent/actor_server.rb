require 'drb/drb'
require 'concurrent/actor_method_dispatcher'

module Concurrent

  class ActorServer

    def initialize(opts = {})
      @port = opts[:port] || 8787
      @host = opts[:host] || 'localhost'

      @receivers = {}

      @dispatcher = ActorMethodDispatcher.new
      @drb_server = DRb.start_service(server_uri, @dispatcher)
    end

    def add(name, instance)
      @receivers[name] = instance
    end


    private

    def server_uri
      "druby://#{@host}:#{@port}"
    end

  end
end
