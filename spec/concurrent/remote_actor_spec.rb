require 'spec_helper'
require_relative 'actor_shared'

module Concurrent

  describe RemoteActor do

    let(:remote_id) { :echo }

    context 'behavior' do

      # actor

      let(:actor_server) do
        clazz = Class.new(Concurrent::Actor){
          def act(*message)
            actor_shared_test_message_processor(*message)
          end
        }
        server = Concurrent::ActorServer.new('localhost', 9999)
        server.pool(remote_id, clazz)
        server
      end

      let(:actor_client) do
        client = Concurrent::RemoteActor.new(remote_id, host: 'localhost', port: 9999)
        client.run!
        client
      end

      it_should_behave_like :actor
    end

    let(:server)    { Concurrent::ActorServer.new }
    subject         { Concurrent::RemoteActor.new(remote_id) }

    class MyRemoteActor < Concurrent::Actor
      attr_accessor :last_message
      def act(*message)
        @last_message = message.first
      end
    end

    let(:remote_actor_class) { MyRemoteActor }

    before { server.pool('foo', MyRemoteActor) }

    context '#start' do

      before { server.run! }

      it 'establishes a remote DRb connection' do
        subject.should be_connected
      end

      it 'returns true on success' do
        subject.post('foo').should be_true
      end

      it 'returns false when not running' do
        subject.stop
        subject.post('foo').should be_false
      end

      it 'sets #last_connection_error on failure' do
      end

      it 'is #ready? once started' do
        subject.should be_ready
      end
    end

    context '#stop' do

      it 'shuts down an active DRb connection' do
        subject.stop
        subject.instance_variable_get('@server').should be_nil
      end

      it 'returns true' do
        subject.stop.should be_true
      end

      it 'is not #ready? when not running' do
        subject.stop
        subject.should_not be_ready
      end
    end

    context 'DRb error while running' do

      it 'is not #running? after DRb error' do

      end

      it 'is not #ready? after DRb error' do
      end

      it 'sets #last_connection_error to the raised exception'
    end

    context 'messaging' do

      it 'does not forward messages when DRb is not connected'

      specify '#post forwards to the remote actor' do
        subject.post('expected')
      end

      specify '#post? forwards to the remote actor'

      specify '#post? obligation is rejected on DRb error'

      specify '#post? obligation reason is set to raises DRb error'

      specify '#post! forwards to the remote actor'

      specify '#post! re-raises DRb error'

      specify '#forward forwards to the remote actor'

      specify '#forward forwards result to the specified local receiver on success'

      specify '#forward forwards result to the specified remote receiver on success'
    end
  end
end
