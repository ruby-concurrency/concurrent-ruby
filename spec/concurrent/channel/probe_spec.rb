require 'spec_helper'
require_relative '../observable_shared'

module Concurrent

  describe Channel::Probe do

    let(:channel) { Object.new }
    let(:probe) { Channel::Probe.new }

    describe 'behavior' do

      # observable
      
      subject{ Channel::Probe.new }
      
      def trigger_observable(observable)
        observable.set('value')
      end

      it_should_behave_like :observable
    end

    describe '#set_unless_assigned' do
      context 'empty probe' do
        it 'assigns the value' do
          probe.set_unless_assigned(32, channel)
          expect(probe.value).to eq 32
        end

        it 'assign the channel' do
          probe.set_unless_assigned(32, channel)
          expect(probe.channel).to be channel
        end

        it 'returns true' do
          expect(probe.set_unless_assigned('hi', channel)).to eq true
        end
      end

      context 'fulfilled probe' do
        before(:each) { probe.set([27, nil]) }

        it 'does not assign the value' do
          probe.set_unless_assigned(88, channel)
          expect(probe.value).to eq 27
        end

        it 'returns false' do
          expect(probe.set_unless_assigned('hello', channel)).to eq false
        end
      end

      context 'rejected probe' do
        before(:each) { probe.fail }

        it 'does not assign the value' do
          probe.set_unless_assigned(88, channel)
          expect(probe).to be_rejected
        end

        it 'has a nil value' do
          expect(probe.value).to be_nil
        end

        it 'has a nil channel' do
          expect(probe.channel).to be_nil
        end

        it 'returns false' do
          expect(probe.set_unless_assigned('hello', channel)).to eq false
        end
      end
    end

  end
end
