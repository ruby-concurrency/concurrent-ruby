require 'socket'
require 'delegate'
require 'functional'
require 'concurrent/reactor'

module Concurrent

  class TcpSyncDemux

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

    def accept
      @session = @server.accept if @session.nil?
      event, args = get_message(@session)
      return nil if event.nil?
      return Reactor::EventContext.new(event, args)
    end

    def respond(result, message)
      return nil if @session.nil?
      @session.puts(format_message(result, message))
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
    def format_message(*args) self.class.format_message(*args); end

    def self.parse_message(message)
      return atomic {
        event = message.first.match /^:?(\w+)/
        event = event[1].to_s.downcase.to_sym unless event.nil?

        args = message.slice(1, message.length) || []

        [event, args]
      }
    end
    def parse_message(*args) self.class.parse_message(*args); end

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
    def get_message(*args) self.class.get_message(*args); end
  end

  TcpSyncDemultiplexer = TcpSyncDemux
end
