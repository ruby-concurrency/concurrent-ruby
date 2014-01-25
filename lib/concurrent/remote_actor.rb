require 'concurrent/actor'
require 'concurrent/postable'
require 'drb/drb'

module Concurrent

  # For some odd reason the class name ActorClient was bothering me. It perfectly
  # describes the rols of the class so it shouldn't bother me, but it does. I'm
  # not sure I like RemoteActor better, though. You know what they say,
  # the hardest part is naming things...
  # -Jerry
  class RemoteActor < Actor

    DEFAULT_HOST = ActorServer::DEFAULT_HOST
    DEFAULT_PORT = ActorServer::DEFAULT_PORT

    attr_accessor :last_connection_error

    def initialize(remote_id, host = DEFAULT_HOST, port = DEFAULT_PORT)
      @remote_id = remote_id
      #@server    = DRbObject.new_with_uri("druby://#{@localhost}:#{@port}") # TODO - connection pool
    end

    protected

    def act(*message)
      # send message to ActorServer over DRb
      # process the result
      # let Actor do the rest
    end
  end
end
