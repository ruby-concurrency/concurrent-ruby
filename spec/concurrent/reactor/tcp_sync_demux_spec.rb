require 'spec_helper'
require 'faker'
require_relative 'sync_demux_shared'

module Concurrent
  class Reactor

    describe TcpSyncDemux, not_on_travis: true do

      subject do
        @subject = TcpSyncDemux.new
      end

      after(:each) do
        @subject.stop unless @subject.nil?
      end

      it_should_behave_like 'synchronous demultiplexer'

      context '#initialize' do

        it 'uses the given host' do
          demux = TcpSyncDemux.new(host: 'www.foobar.com')
          demux.host.should eq 'www.foobar.com'
        end

        it 'uses the default host when none is given' do
          demux = TcpSyncDemux.new
          demux.host.should eq TcpSyncDemux::DEFAULT_HOST
        end

        it 'uses the given port' do
          demux = TcpSyncDemux.new(port: 4242)
          demux.port.should eq 4242
        end

        it 'uses the default port when none is given' do
          demux = TcpSyncDemux.new
          demux.port.should eq TcpSyncDemux::DEFAULT_PORT
        end

        it 'uses the given ACL' do
          acl = %w[deny all]
          ACL.should_receive(:new).with(acl).and_return(acl)
          demux = TcpSyncDemux.new(acl: acl)
          demux.acl.should eq acl
        end

        it 'uses the default ACL when given' do
          acl = TcpSyncDemux::DEFAULT_ACL
          ACL.should_receive(:new).with(acl).and_return(acl)
          demux = TcpSyncDemux.new
          demux.acl.should eq acl
        end
      end

      context '#start' do

        it 'creates a new TCP server' do
          TCPServer.should_receive(:new).with(TcpSyncDemux::DEFAULT_HOST, TcpSyncDemux::DEFAULT_PORT)
          subject.start
        end
      end

      context '#stop' do

        it 'closes the socket' do
        end

        it 'closes the TCP server' do
        end
      end

      context '#accept' do

        it 'returns a correct EventContext object' do
        end

        it 'returns nil on exception' do
        end

        it 'returns nil if the ACL rejects the client' do
        end

        it 'stops and restarts itself on exception' do
        end
      end

      context '#respond' do

        it 'puts a message on the socket' do
        end
      end

      context '#close' do

        it 'closes the socket' do
        end
      end

      specify 'integration', not_on_travis: true do

        # server
        demux = Concurrent::Reactor::TcpSyncDemux.new
        reactor = Concurrent::Reactor.new(demux)

        reactor.add_handler(:echo) {|*args| args.first }
        reactor.add_handler(:error) {|*args| raise StandardError.new(args.first) }
        reactor.add_handler(:unknown) {|*args| args.first }
        reactor.add_handler(:abend) {|*args| args.first }

        t = Thread.new { reactor.start }
        sleep(0.1)

        # client
        there = TCPSocket.open(TcpSyncDemux::DEFAULT_HOST, TcpSyncDemux::DEFAULT_PORT)

        # test :ok
        10.times do
          message = Faker::Company.bs
          there.puts(Concurrent::Reactor::TcpSyncDemux.format_message(:echo, message))
          result, echo = Concurrent::Reactor::TcpSyncDemux.get_message(there)
          result.should eq :ok
          echo.first.should eq message
        end

        # test :ex
        there.puts(Concurrent::Reactor::TcpSyncDemux.format_message(:error, 'error'))
        result, echo = Concurrent::Reactor::TcpSyncDemux.get_message(there)
        result.should eq :ex
        echo.first.should eq 'error'

        # test :noop
        there.puts(Concurrent::Reactor::TcpSyncDemux.format_message(:bogus, 'bogus'))
        result, echo = Concurrent::Reactor::TcpSyncDemux.get_message(there)
        result.should eq :noop
        echo.first.should =~ /bogus/

        # test handler error
        ex = ArgumentError.new('abend')
        ec = Reactor::EventContext.new(:abend, [])
        Reactor::EventContext.should_receive(:new).with(:abend, []).and_return(ec)
        reactor.should_receive(:handle_event).with(ec).and_raise(ex)
        there.puts(Concurrent::Reactor::TcpSyncDemux.format_message(:abend))
        result, echo = Concurrent::Reactor::TcpSyncDemux.get_message(there)
        result.should eq :abend
        echo.first.should eq 'abend'

        #cleanup
        reactor.stop
        sleep(0.1)
        Thread.kill(t)
        sleep(0.1)
      end
    end
  end
end
