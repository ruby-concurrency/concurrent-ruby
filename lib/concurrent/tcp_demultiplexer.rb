require 'socket'
require 'delegate'
require 'functional'
require 'concurrent/reactor'

#----------------------------------------------------------------------------------------------------------
# SERVER
#----------------------------------------------------------------------------------------------------------
#>> require 'socket' #=> false
#>> server = TCPServer.new('localhost', 8080) #=> #<TCPServer:fd 11>
#>> request = Concurrent::TcpRequest.new(server.accept)
#=> #<Concurrent::TcpRequest:0x007f8c8b236e68 @socket=#<TCPSocket:fd 10>, @event=:echo, @args=["foo"]>
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
      return Reactor::EventContext.new(@session.event, @session.args)
    end

    def respond(response)
      @session.puts(response)
      #atomic {
        #@session.puts(response)
        #self.close
      #}
    end

    def close
      @session.close
      @session = nil
    end

    def self.format_message(event, *args)
      args = args.reduce('') do |memo, arg|
        memo << "#{arg}\r\n"
      end
      return "#{event}\r\n#{args}\r\n"
    end

    private

    class TcpSession < Delegator

      attr_reader :event
      attr_reader :args

      def initialize(session)
        super
        @session = session

        message = []
        while line = @session.gets.strip
          break if line.empty?
          message << line
        end

        @event, @args = parse_input(message)
      end

      def __getobj__
        @session
      end

      def __setobj__(obj)
        @session = obj
      end

      private

      def parse_input(message)
        return Kernel.atomic {
          event = message.first.match /^:?(\w+)/
          event = event[1].to_s.downcase.to_sym unless event.nil?

          args = message.slice(1, message.length) || []

          [event, args]
        }
      end
    end
  end

  TcpDemux = TcpDemultiplexer
end
