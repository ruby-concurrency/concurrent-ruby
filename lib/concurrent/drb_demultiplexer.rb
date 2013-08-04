require 'drb/drb'
require 'functional'
require 'concurrent/reactor'

module Concurrent

  class DrbDemultiplexer

    behavior(:sync_event_demux)

    DEFAULT_URI = 'druby://localhost:12345'

    def initialize(uri = nil)
      @uri = uri || DEFAULT_URI
    end

    def set_reactor(reactor)
      raise ArgumentError.new('invalid reactor') unless reactor.behaves_as?(:demux_reactor)
      @reactor = reactor
    end

    def start
      print "Starting Drb service on #{@uri}\n"
      DRb.start_service(@uri, Demultiplexer.new(@reactor))
    end

    def stop
      print "Stopping Drb service\n"
      DRb.start_service
    end

    private

    class Demultiplexer

      def initialize(reactor)
        @reactor = reactor
      end

      def stop
        return false
      end

      def method_missing(method, *args, &block)
        print "///--->>> #{method}\n"
        result = @reactor.handle(method, *args)
        print "<<<---\\\\\\ #{result}\n"
        if result.first == :ok
          return result.last
        else
          return nil
        end
      end
    end
  end
end
