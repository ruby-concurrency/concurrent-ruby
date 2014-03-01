require 'concurrent/actor'
require 'concurrent/postable'
require 'drb/drb'

module Concurrent

  class RemoteActorDrbProxy

    DEFAULT_HOST = ActorServer::DEFAULT_HOST
    DEFAULT_PORT = ActorServer::DEFAULT_PORT

    def initialize(opts = {})
      @host = opts.fetch(:host, DEFAULT_HOST)
      @port = opts.fetch(:port, DEFAULT_PORT)
    end

    def start
      @server ||= DRbObject.new_with_uri("druby://#{@host}:#{@port}") # TODO - connection pool
    end

    def running?
      ! @server.nil?
    end

    def stop
      @server = nil
    end

    def send(remote_id, *message)
      @server.post(remote_id, *message) if running?
    end
  end

  class RemoteActor < Actor

    def initialize(remote_id, opts = {})
      @remote_id = remote_id
      @proxy = opts.fetch(:proxy, RemoteActorDrbProxy.new(opts))
    end

    def connected?
      @proxy.running?
    end

    def running?
      super && connected?
    end

    protected

    def on_run
      @proxy.start
    end

    def on_stop
      @proxy.stop
    end

    def act(*message)
      # at this point we have no way of knowing which of the "post" variant methods was called
      #   we could be here because of #post, #post?, #post!, or #forward
      # the Actor parent class will handle the method-specific behavior
      #   this method simply needs to call across the network
      # this method in a local actor blocks then either returns the result or raises an exception
      #   so this methods should do the same
      #   which means that a DRb error here should be raised normally
      #   which means my #last_connection_error was probably a completely wrong approach
      
      @proxy.send(@remote_id, *message)
    end
  end
end
