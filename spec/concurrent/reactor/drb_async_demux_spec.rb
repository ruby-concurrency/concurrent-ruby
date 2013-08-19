require 'spec_helper'
require 'faker'

module Concurrent
  class Reactor

    describe DRbAsyncDemux, not_on_travis: true do

      subject{ DRbAsyncDemux.new }

      after(:each) do
        DRb.stop_service
      end

      def post_event(demux, event, *args)
        there = DRbObject.new_with_uri(DRbAsyncDemux::DEFAULT_URI)
        there.send(event, *args)
      end

      context '#initialize' do

        it 'sets the initial state to :stopped' do
          subject.should be_stopped
        end

        it 'uses the given URI' do
          uri = 'druby://concurrent-ruby.com:4242'
          demux = DRbAsyncDemux.new(uri: uri)
          demux.uri.should eq uri
        end

        it 'uses the default URI when none given' do
          demux = DRbAsyncDemux.new
          demux.uri.should eq DRbAsyncDemux::DEFAULT_URI
        end

        it 'uses the given ACL' do
          acl = %w[deny all]
          ACL.should_receive(:new).with(acl).and_return(acl)
          demux = DRbAsyncDemux.new(acl: acl)
          demux.acl.should eq acl
        end

        it 'uses the default ACL when given' do
          acl = DRbAsyncDemux::DEFAULT_ACL
          ACL.should_receive(:new).with(acl).and_return(acl)
          demux = DRbAsyncDemux.new
          demux.acl.should eq acl
        end
      end

      context '#start' do

        it 'raises an exception if already started' do
          subject.start

          lambda {
            subject.start
          }.should raise_error(StandardError)
        end

        it 'installs the ACL' do
          acl = %w[deny all]
          ACL.should_receive(:new).once.with(acl).and_return(acl)
          DRb.should_receive(:install_acl).once.with(acl)
          demux = DRbAsyncDemux.new(acl: acl)
          reactor = Concurrent::Reactor.new(demux)
          Thread.new{ reactor.start }
          sleep(0.1)
          reactor.stop
        end

        it 'starts DRb' do
          uri = DRbAsyncDemux::DEFAULT_URI
          DRb.should_receive(:start_service).with(uri, anything())
          demux = DRbAsyncDemux.new(uri: uri)
          reactor = Concurrent::Reactor.new(demux)
          Thread.new{ reactor.start }
          sleep(0.1)
          reactor.stop
        end
      end

      context '#stop' do

        it 'stops DRb' do
          DRb.should_receive(:stop_service).at_least(1).times
          subject.start
          sleep(0.1)
          subject.stop
        end
      end

      context '#stopped?' do

        it 'returns true when stopped' do
          subject.start
          sleep(0.1)
          subject.stop
          sleep(0.1)
          subject.should be_stopped
        end

        it 'returns false when running' do
          subject.start
          sleep(0.1)
          subject.should_not be_stopped
        end
      end

      context '#set_reactor' do

        it 'raises an exception when given an invalid reactor' do
          lambda {
            subject.set_reactor(Concurrent::Reactor.new)
          }.should_not raise_error

          lambda {
            subject.set_reactor('bogus')
          }.should raise_error(ArgumentError)
        end
      end

      context 'event handling' do

        it 'should post events to the reactor' do
          demux = subject
          reactor = Concurrent::Reactor.new(demux)
          reactor.add_handler(:foo){ nil }
          reactor.should_receive(:handle).with(:foo, 1,2,3).and_return([:ok, nil])

          Thread.new { reactor.start }
          sleep(0.1)

          post_event(demux, :foo, 1, 2, 3)

          reactor.stop
          sleep(0.1)
        end
      end

      specify 'integration', not_on_travis: true do

        # server
        demux = Concurrent::Reactor::DRbAsyncDemux.new
        reactor = Concurrent::Reactor.new(demux)

        reactor.add_handler(:echo) {|message| message }
        reactor.add_handler(:error) {|message| raise StandardError.new(message) }
        reactor.add_handler(:unknown) {|message| message }
        reactor.add_handler(:abend) {|message| message }

        t = Thread.new { reactor.start }
        sleep(0.1)

        # client
        there = DRbObject.new_with_uri(DRbAsyncDemux::DEFAULT_URI)

        # test :ok
        10.times do
          message = Faker::Company.bs
          echo = there.echo(message)
          echo.should eq message
        end

        # test :ex
        lambda {
          echo = there.error('error')
        }.should raise_error(StandardError, 'error')

        # test :noop
        lambda {
          echo = there.bogus('bogus')
        }.should raise_error(NoMethodError)

        # test unknown respone code
        reactor.should_receive(:handle).with(:unknown).and_return([:unknown, nil])
        lambda {
          echo = there.unknown
        }.should raise_error(DRb::DRbError)

        # test handler error
        reactor.should_receive(:handle).with(:abend).and_raise(ArgumentError)
        lambda {
          echo = there.abend
        }.should raise_error(DRb::DRbRemoteError)

        # cleanup
        reactor.stop
        sleep(0.1)
        Thread.kill(t)
        sleep(0.1)
      end
    end
  end
end
