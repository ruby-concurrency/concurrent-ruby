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

    behavior(:sync_event_demux)

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

    def stopped?
      return @server.nil?
    end

    #def accept
      #@session = @server.accept if @session.nil?

      #message = []
      #while line = @session.gets
        #if line.nil? || (line = line.strip).empty?
          #break
        #else
          #message << line
        #end
      #end

      #if message.empty?
        #return nil
      #else
        #event, args = self.class.parse_message(message)
        #return Reactor::EventContext.new(event, args)
      #end
    #end

    def accept
      @session = @server.accept if @session.nil?
      event, args = self.class.get_message(@session)
      return nil if event.nil?
      return Reactor::EventContext.new(event, args)
    end

    def respond(response)
      return nil if @session.nil?
      @session.puts(response)
    end

    def close
      @session.close
      @session = nil
    end

    def self.format_message(event, *args)
      args = args.reduce('') do |memo, arg|
        memo << "#{arg}\r\n"
      end
      return ":#{event}\r\n#{args}\r\n"
    end

    def self.parse_message(message)
      return atomic {
        event = message.first.match /^:?(\w+)/
        event = event[1].to_s.downcase.to_sym unless event.nil?

        args = message.slice(1, message.length) || []

        [event, args]
      }
    end

    def self.get_message(socket)
      message = []
      while line = socket.gets
        if line.nil? || (line = line.strip).empty?
          break
        else
          message << line
        end
      end

      if message.empty?
        return nil
      else
        return parse_message(message)
      end
    end
  end

  TcpDemux = TcpDemultiplexer
end
