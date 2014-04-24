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
          probe.value.should eq 32
        end

        it 'assign the channel' do
          probe.set_unless_assigned(32, channel)
          probe.channel.should be channel
        end

        it 'returns true' do
          probe.set_unless_assigned('hi', channel).should eq true
        end
      end

      context 'fulfilled probe' do
        before(:each) { probe.set([27, nil]) }

        it 'does not assign the value' do
          probe.set_unless_assigned(88, channel)
          probe.value.should eq 27
        end

        it 'returns false' do
          probe.set_unless_assigned('hello', channel).should eq false
        end
      end

      context 'rejected probe' do
        before(:each) { probe.fail }

        it 'does not assign the value' do
          probe.set_unless_assigned(88, channel)
          probe.should be_rejected
        end

        it 'has a nil value' do
          probe.value.should be_nil
        end

        it 'has a nil channel' do
          probe.channel.should be_nil
        end

        it 'returns false' do
          probe.set_unless_assigned('hello', channel).should eq false
        end
      end
    end

  end
end
