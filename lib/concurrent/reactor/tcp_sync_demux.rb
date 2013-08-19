require 'socket'
require 'drb/acl'
require 'functional'
require 'concurrent/reactor'

module Concurrent
  class Reactor

    class TcpSyncDemux

      behavior(:sync_event_demux)

      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = 12345
      DEFAULT_ACL = %w{deny all allow 127.0.0.1}

      attr_reader :host
      attr_reader :port
      attr_reader :acl

      def initialize(opts = {})
        @host = opts[:host] || DEFAULT_HOST
        @port = opts[:port] || DEFAULT_PORT
        @acl = ACL.new(opts[:acl] || DEFAULT_ACL)
      end

      def run
        raise StandardError.new('already running') if running?
        begin
          @server = TCPServer.new(@host, @port)
          return true
        rescue Exception => ex
          return false
        end
      end

      def stop
        @socket.close unless @socket.nil?
        @server.close unless @server.nil?
        @server = @socket = nil
      end

      def reset
        stop
        sleep(1)
        run
      end

      def running?
        return ! @server.nil?
      end

      def accept
        @socket = @server.accept if @socket.nil?
        return nil unless @acl.allow_socket?(@socket)
        event, args = get_message(@socket)
        return nil if event.nil?
        return Reactor::EventContext.new(event, args)
      rescue Exception => ex
        reset
      end

      def respond(result, message)
        return nil if @socket.nil?
        @socket.puts(format_message(result, message))
      rescue Exception => ex
        reset
      end

      def self.format_message(event, *args)
        args = args.reduce('') do |memo, arg|
          memo << "#{arg}\r\n"
        end
        return ":#{event}\r\n#{args}\r\n"
      end

      def format_message(*args)
        self.class.format_message(*args)
      end

      def self.parse_message(message)
        event = message.first.match /^:?(\w+)/
        event = event[1].to_s.downcase.to_sym unless event.nil?
        args = message.slice(1, message.length) || []
        return [event, args]
      end

      def parse_message(*args)
        self.class.parse_message(*args)
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
      def get_message(*args) self.class.get_message(*args); end
    end

    TcpSyncDemultiplexer = TcpSyncDemux
  end
end
