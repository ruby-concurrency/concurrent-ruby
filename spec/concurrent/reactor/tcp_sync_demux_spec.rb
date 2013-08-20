require 'spec_helper'
require 'faker'

module Concurrent
  class Reactor

    describe TcpSyncDemux, not_on_travis: true do

      subject do
        @subject = TcpSyncDemux.new(port: 2000 + rand(8000))
      end

      after(:each) do
        @subject.stop unless @subject.nil?
      end

      context '#initialize' do

        it 'sets the initial state to :stopped' do
          subject.should_not be_running
        end

        it 'raises an exception if already runed' do
          subject.run

          lambda {
            subject.run
          }.should raise_error(StandardError)
        end

        it 'uses the given host' do
          demux = TcpSyncDemux.new(host: 'www.foobar.com')
          demux.host.should eq 'www.foobar.com'
          demux.stop
        end

        it 'uses the default host when none is given' do
          demux = TcpSyncDemux.new
          demux.host.should eq TcpSyncDemux::DEFAULT_HOST
          demux.stop
        end

        it 'uses the given port' do
          demux = TcpSyncDemux.new(port: 4242)
          demux.port.should eq 4242
          demux.stop
        end

        it 'uses the default port when none is given' do
          demux = TcpSyncDemux.new
          demux.port.should eq TcpSyncDemux::DEFAULT_PORT
          demux.stop
        end

        it 'uses the given ACL' do
          acl = %w[deny all]
          ACL.should_receive(:new).with(acl).and_return(acl)
          demux = TcpSyncDemux.new(acl: acl)
          demux.acl.should eq acl
          demux.stop
        end

        it 'uses the default ACL when given' do
          acl = TcpSyncDemux::DEFAULT_ACL
          ACL.should_receive(:new).with(acl).and_return(acl)
          demux = TcpSyncDemux.new
          demux.acl.should eq acl
          demux.stop
        end
      end

      context '#run' do

        it 'creates a new TCP server' do
          TCPServer.should_receive(:new).with(TcpSyncDemux::DEFAULT_HOST, anything())
          subject.run
        end

        it 'returns true on success' do
          TCPServer.stub(:new).with(TcpSyncDemux::DEFAULT_HOST, anything())
          subject.run.should be_true
        end

        it 'returns false on failure' do
          TCPServer.stub(:new).with(TcpSyncDemux::DEFAULT_HOST, anything()) \
            .and_raise(StandardError)
          subject.run.should be_false
        end

        it 'raises an exception when already running' do
          subject.run
          lambda {
            subject.run
          }.should raise_error
        end
      end

      context '#stop' do

        let(:server){ double('tcp server') }
        let(:socket){ double('tcp socket') }

        before(:each) do
          socket.stub(:close).with(no_args())
          server.stub(:close).with(no_args())
          subject.run
          subject.instance_variable_set(:@socket, socket)
          subject.instance_variable_set(:@server, server)
        end

        it 'immediately returns true when not running' do
          socket.should_not_receive(:close)
          server.should_not_receive(:close)
          demux = TcpSyncDemux.new
          demux.stop.should be_true
        end

        it 'closes the socket' do
          socket.should_receive(:close).with(no_args())
          subject.stop
        end

        it 'closes the TCP server' do
          server.should_receive(:close).with(no_args())
          subject.stop
        end

        it 'is supresses socket close exceptions' do
          socket.should_receive(:close).and_raise(SocketError)
          lambda {
            subject.stop
          }.should_not raise_error
        end

        it 'supresses server close exceptions' do
          server.should_receive(:close).and_raise(SocketError)
          lambda {
            subject.stop
          }.should_not raise_error
        end
      end

      context '#running?' do

        it 'returns false when stopped' do
          subject.run
          sleep(0.1)
          subject.stop
          sleep(0.1)
          subject.should_not be_running
        end

        it 'returns true when running' do
          subject.run
          sleep(0.1)
          subject.should be_running
        end
      end

      context '#reset' do

        it 'closes the demux' do
          subject.should_receive(:run).exactly(2).times.and_return(true)
          subject.run
          sleep(0.1)
          subject.reset
        end

        it 'starts the demux' do
          # add one call to #stop for the :after clause
          subject.should_receive(:stop).exactly(2).times.and_return(true)
          sleep(0.1)
          subject.reset
        end
      end

      context '#accept' do

        let!(:event){ :echo }
        let!(:message){ 'hello world' }

        def setup_demux
          @demux = TcpSyncDemux.new(host: 'localhost', port: 5555, acl: %w[allow all])
          @demux.run
        end

        def send_event_message
          there = TCPSocket.open('localhost', 5555)
          @thread = Thread.new do
            there.puts(@demux.format_message(event, message))
          end

          @expected = nil
          Timeout::timeout(2) do
            @expected = @demux.accept
          end
          @thread.join(1)
        end

        after(:each) do
          @demux.stop unless @demux.nil?
          Thread.kill(@thread) unless @thread.nil?
          @expected = @demux = @thread = nil
        end

        it 'returns a correct EventContext object' do
          setup_demux
          send_event_message
          @expected.should be_a(EventContext)
          @expected.event.should eq :echo
          @expected.args.should eq ['hello world']
          @expected.callback.should be_nil
        end

        it 'returns nil on exception' do
          setup_demux
          @demux.should_receive(:get_message).with(any_args()).and_raise(StandardError)
          send_event_message
          @expected.should be_nil
        end

        it 'returns nil if the ACL rejects the client' do
          acl = double('acl')
          acl.should_receive(:allow_socket?).with(anything()).and_return(false)
          ACL.should_receive(:new).with(anything()).and_return(acl)
          setup_demux
          send_event_message
          @expected.should be_nil
        end

        it 'resets the demux on exception' do
          setup_demux
          @demux.should_receive(:get_message).with(any_args()).and_raise(StandardError)
          @demux.should_receive(:reset).with(no_args())
          send_event_message
        end
      end

      context '#respond' do

        it 'returns nil if the socket is nil' do
          subject.stop
          subject.respond(:ok, 'foo').should be_nil
        end

        it 'puts a message on the socket' do
          socket = double('tcp socket')
          socket.should_receive(:puts).with("ok\r\necho\r\n\r\n")
          subject.instance_variable_set(:@socket, socket)
          subject.respond(:ok, 'echo')
        end

        it 'resets the demux on exception' do
          socket = double('tcp socket')
          socket.should_receive(:puts).and_raise(SocketError)
          subject.instance_variable_set(:@socket, socket)
          subject.should_receive(:reset)
          subject.respond(:ok, 'echo')
        end
      end

      context '#format_message' do

        it 'raises an exception when the event is nil' do
          lambda {
            subject.format_message(nil)
          }.should raise_error(ArgumentError)

          lambda {
            TcpSyncDemux.format_message(nil)
          }.should raise_error(ArgumentError)
        end

        it 'raises an exception when the event is an empty string' do
          lambda {
            subject.format_message('  ')
          }.should raise_error(ArgumentError)

          lambda {
            TcpSyncDemux.format_message('   ')
          }.should raise_error(ArgumentError)
        end

        it 'creates a message with no arguments' do
          message = subject.format_message(:echo)
          message.should eq "echo\r\n\r\n"

          message = TcpSyncDemux.format_message('echo')
          message.should eq "echo\r\n\r\n"
        end

        it 'creates a message with arguments' do
          message = subject.format_message(:echo, 'hello', 'world')
          message.should eq "echo\r\nhello\r\nworld\r\n\r\n"

          message = TcpSyncDemux.format_message('echo', 'hello', 'world')
          message.should eq "echo\r\nhello\r\nworld\r\n\r\n"
        end
      end

      context '#parse_message' do

        it 'accepts the message as a string' do
          message = subject.parse_message("echo\r\nhello world\r\n\r\n")
          message.should_not eq [nil, nil]
        end

        it 'accepts the message as an array of lines' do
          message = subject.parse_message(%w[echo hello world])
          message.should_not eq [nil, nil]
        end

        it 'recognizes an event name beginning with a colon' do
          message = subject.parse_message(":echo\r\nhello world\r\n\r\n")
          message.first.should eq :echo

          message = TcpSyncDemux.parse_message(%w[:echo hello world])
          message.first.should eq :echo
        end

        it 'recognizes an event name without a beginning colon' do
          message = subject.parse_message(%w[echo hello world])
          message.first.should eq :echo

          message = TcpSyncDemux.parse_message("echo\r\nhello world\r\n\r\n")
          message.first.should eq :echo
        end

        it 'parses a message without arguments' do
          message = subject.parse_message("echo\r\n\r\n")
          message.first.should eq :echo

          message = TcpSyncDemux.parse_message(%w[echo])
          message.first.should eq :echo
        end

        it 'parses a message with arguments' do
          message = subject.parse_message(%w[echo hello world])
          message.last.should eq %w[hello world]

          message = TcpSyncDemux.parse_message("echo\r\nhello world\r\n\r\n")
          message.last.should eq ['hello world']
        end

        it 'returns nil for a malformed message' do
          message = subject.parse_message(nil)
          message.should eq [nil, []]

          message = subject.parse_message('    ')
          message.should eq [nil, []]
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

        t = Thread.new { reactor.run }
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
