require 'socket'
require 'functional'
require 'concurrent/reactor'

#>> require 'socket' #=> false
#>> server = TCPServer.new('localhost', 8080) #=> #<TCPServer:fd 11>
#>> session = server.accept #=> #<TCPSocket:fd 12>
#>> p sesion
#>> p session #=> #<TCPSocket:fd 12>
##<TCPSocket:fd 12>
#>> session.gets #=> "GET / HTTP/1.1\r\n"
#>> server.close #=> nil
#>> session.close #=> nil
#>> server = TCPServer.new('localhost', 8080) #=> #<TCPServer:fd 11>
#>> session = server.accept #=> #<TCPSocket:fd 12>
#>> session.gets #=> "GET /one/two/three.xml?foo=bar&baz=boom HTTP/1.1\r\n"
#>> session.print "HTTP/1.1 200/OK\r\n\r\n" #=> nil
#>> session.puts "HTTP/1.1 200/OK\r\n\r\n" #=> nil
#>> session.close #=> nil

module Concurrent

  class HttpDemultiplexer

    #behavior(:sync_event_demux)

    DEFAULT_HOST = '127.0.0.1'
    DEFAULT_PORT = 12345

    def initialize(opts = {})
      @host = opts[:host] || DEFAULT_HOST
      @port = opts[:port] || DEFAULT_PORT
      @server = TCPServer.new(@host, @port)
    end

    def accept
    end

    def respond(response)
    end
  end
end
