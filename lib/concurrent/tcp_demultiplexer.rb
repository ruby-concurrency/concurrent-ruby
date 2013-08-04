require 'socket'
require 'functional'
require 'concurrent/reactor'

#----------------------------------------------------------------------------------------------------------
# SERVER
#----------------------------------------------------------------------------------------------------------
#>> require 'socket' #=> false
#>> server = TCPServer.new('localhost', 8080) #=> #<TCPServer:fd 11>
#>> request = Concurrent::TcpRequest.new(server.accept)
#=> #<Concurrent::TcpRequest:0x007f8c8b236e68 @socket=#<TCPSocket:fd 10>, @event=:echo, @arguments=["foo"]>
#>> request.close #=> nil
#----------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------
# CLIENT
#----------------------------------------------------------------------------------------------------------
# [11:55:49 Jerry ~/Projects/FOSS/concurrent-ruby (reactor)]$ telnet localhost 8080
# Trying 127.0.0.1...
# Connected to localhost.
# Escape character is '^]'.
# :echo
# foo

# Connection closed by foreign host.
#----------------------------------------------------------------------------------------------------------



module Concurrent

  class TcpDemultiplexer

    #behavior(:sync_event_demux)

    DEFAULT_HOST = '127.0.0.1'
    DEFAULT_PORT = 12345

    def initialize(opts = {})
      @host = opts[:host] || DEFAULT_HOST
      @port = opts[:port] || DEFAULT_PORT
    end

    def start
      @server = TCPServer.new(@host, @port)
    end

    def stop
      atomic {
        @session.close unless @session.nil?
        @server.close unless @server.nil?
        @server = @session = nil
      }
    end

    def accept
      @session = TcpSession.new(@server.accept)
      return Reactor::EventContext(@session.event, @session.arguments)
    end

    def respond(response)
      atomic {
        @session.puts(response)
        self.close
      }
    end

    def close
      @session.close
    end

    private

    class TcpSession

      attr_reader :event
      attr_reader :arguments
      alias_method :args, :arguments

      def initialize(socket)
        @socket = socket

        message = []
        while line = socket.gets.strip
          break if line.empty?
          message << line
        end

        @event, @arguments = parse_input(message)
      end

      def close
        @socket.close
        @socket = nil
      end

      private

      def parse_input(message)
        return atomic {
          event = message.first.match /^:?(\w+)/
          event = event[1].to_s.downcase.to_sym unless event.nil?

          args = message.slice(1, message.length) || []

          [event, args]
        }
      end
    end
  end
end
