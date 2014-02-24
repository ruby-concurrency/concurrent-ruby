require 'spec_helper'

module Concurrent

  describe RemoteActor do

    let(:remote_id) { 1 }
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

      it 'returns true on success'

      it 'returns false on failure'

      it 'sets #last_connection_error on failure' do
      end

      it 'is #ready? once started'
    end

    context '#stop' do

      it 'shuts down an active DRb connection'

      it 'returns true'

      it 'is not #ready? when not running'
    end

    context 'DRb error while running' do

      it 'is not #running? after DRb error'

      it 'is not #ready? after DRb error'

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
