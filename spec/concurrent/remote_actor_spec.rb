require 'spec_helper'

module Concurrent

  describe RemoteActor do

    context '#start' do

      it 'establishes a remote DRb connection'

      it 'returns true on success'

      it 'returns false on failure'

      it 'sets #last_connection_error on failure'

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

      let!(:remote_id) { 'foo' }

      let(:remote_actor_class) do
        Class.new(Concurrent::Actor) do
          attr_accessor :last_message
          def act(*message)
            @last_message = message.first
          end
        end
      end

      let(:here) do
        RemoteActor.new(remote_id)
      end

      let(:there) do
        remote_actor_class.new
      end

      let(:server) do
        ActorServer.new
      end

      before(:each) do
        server.add(remote_id, there)
        server.run!
        here.run!
      end

      after(:each) do
        here.stop
        server.stop
      end

      it 'does not forward messages when DRb is not connected'

      specify '#post forwards to the remote actor' do
        here.post('expected')
        sleep(1)
        there.last_message.should eq 'expected'
      end

      specify '#<< forwards to the remote actor' do
        here << 'expected'
        sleep(1)
        there.last_message.should eq 'expected'
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
