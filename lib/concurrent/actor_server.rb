require 'drb/drb'
#require 'concurrent/actor_method_dispatcher'
require 'concurrent/runnable'

module Concurrent

  class ActorServer
    extend Forwardable
    include Runnable

    DEFAULT_HOST = 'localhost'
    DEFAULT_PORT = 8787

    attr_accessor :actor_pool

    #def_delegator :@dispatcher, :add

    def initialize(host = DEFAULT_HOST, port = DEFAULT_PORT)
      @host       = host
      @port       = port
      @actor_pool = {}
    end

    def running?
      super && @drb_server.alive?
    end

    def pool(name, actor, pool_size = 1)
      @actor_pool[name] = new_actor_pool(actor, pool_size)
    end

    # for clarity we may want to give this a different name
    # it isn't the same method as Actor#post
    def post(name, *args)
      #return if @actor_pool[name].nil?

      #@actor_pool[name][:actors].post(args)

      # this method needs to block and return the result
      #   or communicate the exception back to the caller
      # I'm fairly certain that DRb will catch exceptions, send them back,
      #   let the client code re-raise the exception
      # so I think we can just let exceptions be raised
      #
      # so if we want this method to 1) return on success or 2) raise exceptions
      #   then we should be able to just call #post! on the pool
      #   and let it behave normally
      #   one problem: #post! requires a timeout value as the first parameter
      #   one option is to configure the timeout on the server,
      #     but this could lead to weird behavior on the client
      #   another option is to update Postable#post! with a "block indefinitely" option
      #   for this spike I'll just set a long timeout and worry about it later

      raise ArgumentError.new("no registration for #{name}") unless @actor_pool[name]
      # this will block for 30 seconds and return the result
      # if an error is raised by the actor it will be raised by #post!
      # it post! reaches the timeout it will raise Concurrent::TimeoutError
      # DRb should catch the exception and marshall it back to the client
      return @actor_pool[name][:actors].post!(30, *args)
    end

    protected

    def on_run
      start_drb_server unless running?
    end

    def after_run
    end

    def on_task
    end

    def on_stop
      @drb_server.stop_service if running?
    end

    private

    def server_uri
      @server_uri ||= "druby://#{@host}:#{@port}"
    end

    def start_drb_server
      @drb_server = DRb.start_service(server_uri, self)
    end

    def new_actor_pool(actor, size)
      supervisor = Concurrent::Supervisor.new
      actors, pool = actor.pool(size)

      pool.each{ |a| supervisor.add_worker(a) }
      supervisor.run!

      { supervisor: supervisor, actors: actors, pool: pool }
    end
  end
end
