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
      @host      = host
      @port      = port

      establishes_connection
    end

    def connected?
      log_error do
        @server.running?
      end
    end

    def ready?
      connected?
    end

    def post(*message)
      return false unless ready?

      super(@remote_id, message)
      true
    end

    def stop
      @server = nil
      true
    end

    def start
      establishes_connection
    end

    protected

    def act(*message)
      log_error do
        @server.post(@remote_id, message)
      end
    end

    private

    def establishes_connection
      log_error do
        @server = DRbObject.new_with_uri("druby://#{@host}:#{@port}") # TODO - connection pool
      end
    end

    def log_error
      yield
    rescue Exception => ex
      self.last_connection_error = ex.message
      false
    end
  end
end
