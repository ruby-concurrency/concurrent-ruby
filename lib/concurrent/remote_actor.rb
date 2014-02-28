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
      super && connected?
    end

    #def post(*message)
      #return false unless ready?

      #super(@remote_id, message)
      #true
    #end

    #def post?(*message)
    #end

    #def post!(seconds, *message)
    #end

    #def forward(receiver, *message)
    #end

    def stop
      @server = nil
      true
    end

    def start
      establishes_connection
    end

    protected

    def act(*message)
      # at this point we have no way of knowing which of the "post" variant methods was called
      #   we could be here because of #post, #post?, #post!, or #forward
      # the Actor parent class will handle the method-specific behavior
      #   this method simply needs to call across the network
      # this method in a local actor blocks then either returns the result or raises an exception
      #   so this methods should do the same
      #   which means that a DRb error here should be raised normally
      #   which means my #last_connection_error was probably a completely wrong approach

      # we don't want to catch errors here, we want them to bubble up to the Actor superclass
      #log_error do
        #@server.post(@remote_id, message)
      #end
      
      @server.post(@remote_id, *message)
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
